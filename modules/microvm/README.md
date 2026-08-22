# agent-sandbox micro VM

A NixOS micro VM for sandboxing LLM/coding agents, run on Apple Silicon macOS
via [vfkit](https://github.com/crc-org/vfkit) (Apple Virtualization framework)
using [microvm.nix](https://github.com/microvm-nix/microvm.nix).

Based on <https://abhinavsarkar.net/notes/2026-microvm-nix/>.

## Why

The agent runs **inside** the VM. Everything it *executes* — builds, tests,
arbitrary commands, dependency code — is caged. It cannot reach secrets
(`~/.ssh`, tokens, keychains), the rest of the host filesystem, or the system;
networking is NAT-only (outbound only; the host cannot connect into the VM).

This closes the enforcement gap of agent-level permission configs: those gate
what the agent *asks* to do, but anything it legitimately shells out to (a
`make` target, an `npm test`) runs unrestricted. In the VM, that execution is
structurally confined.

## Trust model

Think of the VM as a **second computer with your projects directory plugged
in**:

- `~/projects` is shared **read-write**. Agents work directly in your real
  repos — the same working copy you have open in your editor. You watch and
  edit alongside the agent, exactly as with a host-side agent session.
- **Git is the undo layer, the VM is the execution jail.** The sandbox does
  not protect your repos from the agent — it protects everything *else* from
  whatever the agent runs. Repo safety comes from git (commit/push before
  sessions, reflog, remotes) and from you watching the session.

A read-only share would be cosmetic anyway: vfkit's virtio-fs has no
host-side read-only flag, so `ro` could only be a guest mount option, which
guest root (the agent) can remount rw. Mounting rw states the real trust
model instead of implying a boundary that doesn't exist.

### Consequences worth knowing

- **Commit or stash before letting an agent loose.** Uncommitted work in a
  repo the agent touches is destructible; committed work is always
  recoverable via reflog.
- **`.git` dirs are agent-writable**, including hooks and config
  (`core.hooksPath`, `core.fsmonitor`), which execute host-side when *you*
  run git in that repo. After an unattended/suspect session, glance at
  `.git/config` and hooks, or run
  `git -c core.hooksPath=/dev/null -c core.fsmonitor= <cmd>`.
- **Blast radius is all of `~/projects`**, not just the repo being worked on
  — including this dotfiles repo. Review diffs before a `darwin-rebuild` that
  follows an agent session.
- **The host Nix store is visible read-only** in the VM (shared as the
  overlay's lower layer): an agent can read everything in your `/nix/store`.
  Store writes are blocked host-side by POSIX perms (root-owned), unlike
  `~/projects` which your user owns.

## Files

- `vm.nix` — the guest NixOS config (vfkit, resources, shares, tooling).
  Reuses `modules/common.nix`, so the VM has the same home-manager tooling as
  a normal host (git, go, fish, direnv, opencode, ...) applied to the
  autologin `root` user.
- `darwin.nix` — host-side wiring: the `microvm-run` launcher and the opt-in
  `linux-builder`.
- Wired into all darwin hosts via `hosts/darwin/default.nix`.

## Building & running

The VM is `aarch64-linux`. Its closure is built in CI and pushed to cachix, so
normally you just run it and Nix substitutes the closure:

```sh
microvm-run          # builds/substitutes the VM, then boots it via vfkit
```

Exit the VM with `poweroff` at its shell prompt.

To (re)build the VM locally (e.g. while iterating on `vm.nix`), temporarily
flip `microvm.linuxBuilder.enable = true` in `hosts/darwin/default.nix`,
rebuild + switch, run, then flip it back to free the builder VM's resources.

State locations on the host (per-user, resolved at launch via `$HOME`):

- `~/.local/share/microvm/nix-store-overlay.img` — the VM's writable Nix store
  overlay (persists across runs).
- `~/.local/share/microvm/agent-state.img` — persistent agent state. The VM
  is otherwise stateless (tmpfs root; config comes from the Nix closure), but
  opencode sessions/history (`~/.local/share/opencode`) and herdr session
  state (`~/.config/herdr`) are symlinked onto this volume so they survive
  `poweroff`.

Note: opencode's `auth.json` (API credentials) lives in that persisted state
— same protection class as the host's own `~/.local/share/opencode`, but be
aware the "no secrets in the VM" property now excludes the agent's own login.

## Shares

| Host          | VM (guest)       | Mode | Notes                               |
| ------------- | ---------------- | ---- | ----------------------------------- |
| `~/projects`  | `/root/projects` | rw   | injected at launch (per-user $HOME) |
| `/nix/store`  | `/nix/.ro-store` | ro   | lower layer of the store overlay    |

The projects share's host path is per-user, so it is injected at launch
(resolving `$HOME`) via `extraArgsScript` rather than baked into the closure;
the guest mounts it by tag with `nofail` so a CI-built closure still boots
without it.

## Workflow

There isn't one — that's the point. Boot the VM, `cd ~/projects/<repo>`, start
an agent session (one session per repo). On the host, keep the same directory
open in your editor: you see edits live, you intervene and edit alongside the
agent, and finished work is already in your repo on whatever branch the agent
used. Commit, branch, and push with your normal git habits (pushes happen
host-side — the VM deliberately has no credentials).

The VM's git identity can commit but cannot sign (no keys in the VM); re-sign
on the host if you need signed history.
