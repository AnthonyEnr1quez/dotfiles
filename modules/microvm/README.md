# agent-sandbox micro VM

A NixOS micro VM for sandboxing LLM/coding agents, run on Apple Silicon macOS
via [vfkit](https://github.com/crc-org/vfkit) (Apple Virtualization framework)
using [microvm.nix](https://github.com/microvm-nix/microvm.nix).

Based on <https://abhinavsarkar.net/notes/2026-microvm-nix/>.

## Why

The agent runs **inside** the VM. Everything it does — reading files, running
builds/tests, executing arbitrary commands — is caged. It cannot touch the host
filesystem beyond the directories explicitly shared in, and networking is
NAT-only (outbound only; the host cannot connect into the VM).

## Files

- `vm.nix` — the guest NixOS config (vfkit, resources, shares, tooling). Reuses
  `modules/common.nix`, so the VM has the same home-manager tooling as a normal
  host (git, go, fish, direnv, opencode, ...) applied to the autologin `root`
  user.
- `darwin.nix` — host-side wiring: the `microvm-run` launcher, the opt-in
  `linux-builder`, and the host helpers (`microvm-fetch`, `microvm-open`,
  `microvm-review`).
- Wired into all darwin hosts via `hosts/darwin/default.nix`.

## Building & running

The VM is `aarch64-linux`. Its closure is built in CI and pushed to cachix, so
normally you just run it and Nix substitutes the closure:

```sh
microvm-run          # builds/substitutes the VM, then boots it via vfkit
```

Exit the VM with `poweroff` at its shell prompt.

To (re)build the VM locally (e.g. while iterating on `vm.nix`), temporarily flip
`microvm.linuxBuilder.enable = true` in `hosts/darwin/default.nix`, rebuild +
switch, run, then flip it back to free the builder VM's resources.

State locations on the host (per-user, resolved at launch via `$HOME`):

- `~/.local/share/microvm/nix-store-overlay.img` — the VM's writable Nix store
  overlay (persists across runs).
- `~/.local/share/microvm/worktrees/` — the writable worktrees area (see below).

## Shares

Two host directories are shared into the VM. Their host paths are per-user, so
they are injected at launch (resolving `$HOME`) rather than baked into the
closure; the guest mounts them by tag.

| Host                                    | VM (guest)        | Mode |
| --------------------------------------- | ----------------- | ---- |
| `~/projects`                            | `/root/projects`  | ro   |
| `~/.local/share/microvm/worktrees`      | `/root/worktrees` | rw   |

`~/projects` is **read-only** in the VM: an agent can read your repos but cannot
modify them.

## Worktree workflow

Because `~/projects` is read-only, the agent cannot create a git worktree
directly off your repos (worktrees must write into the main repo's `.git`).
Instead it works in a **self-contained clone** in the writable worktrees area,
and results are pulled back to the host explicitly.

### 1. In the VM — start a session

```sh
new-worktree <repo> [session] [base-branch]
```

- `<repo>` — path under `~/projects` (e.g. `nix/dotfiles`)
- `[session]` — session name (defaults to a timestamp)
- `[base-branch]` — branch to base the work on (defaults to the repo's default)

This makes a `git clone --no-hardlinks ~/projects/<repo>` at
`~/worktrees/<repo>/<session>` (self-contained, so it survives the source repo
being modified/gc'd on the host), checks out `<base-branch>`, and creates a
fresh `agent/<session>` branch. The agent works there and commits onto
`agent/<session>`.

```sh
new-worktree nix/dotfiles fix-thing develop
cd ~/worktrees/nix/dotfiles/fix-thing
# ... agent edits and commits on branch agent/fix-thing ...
```

### 2. On the host — watch live

The session directory is shared live, so you can open it in Zed and watch edits
(including uncommitted changes) in real time:

```sh
microvm-open nix/dotfiles fix-thing    # opens the session dir in Zed (zeditor)
microvm-open nix/dotfiles              # lists sessions for the repo
```

### 3. On the host — pull results into your real repo

`git fetch` only moves committed work. To bring the agent's commits into your
real repo:

```sh
microvm-fetch nix/dotfiles
```

This fetches every session's branches into `~/projects/<repo>` under
`refs/agent/<session>/*` — namespaced so nothing collides with your own
branches and no remotes are left behind.

### 4. On the host — review the fetched work

The fetched refs live under `refs/agent/*`, which aren't normal branches, so
`git switch` won't find them directly. Use `microvm-review` to check a session
out in a host git worktree:

```sh
microvm-review <repo> <session> [branch]
```

- Defaults `[branch]` to the session's `agent/<session>` branch.
- Creates a review worktree at `~/projects/<repo>-review/<session>`, checked out
  at the agent's ref — ready to open in Zed and merge natively.

```sh
microvm-review nix/dotfiles fix-thing
```

Or do it manually:

```sh
git for-each-ref refs/agent                                  # list agent refs
git switch -c review-fix-thing refs/agent/fix-thing/agent/fix-thing
# or:
git worktree add ../review refs/agent/fix-thing/agent/fix-thing
```

## Notes / caveats

- **Isolation vs. native worktrees.** Because the agent runs in the VM and
  `~/projects` is read-only, its work cannot be a *native* git worktree of your
  host repo (that would require host-repo write access, breaking the sandbox).
  You review via the live shared dir + `microvm-fetch` instead of Zed's native
  worktree switcher.
- **Read-only enforcement** for `~/projects` is guest-side (the `ro` mount).
  It's sufficient for sandboxing your own agents, but is not a hard boundary
  against a kernel-level guest exploit.
- **The host Nix store is visible read-only** in the VM (shared as the overlay's
  lower layer), so an agent can read — but not modify — everything in your
  `/nix/store`.
