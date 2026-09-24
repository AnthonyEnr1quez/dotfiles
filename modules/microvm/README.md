# agent-sandbox microVMs

Host-specific NixOS microVMs for sandboxing LLM/coding agents. They run on
Apple Silicon macOS through [vfkit](https://github.com/crc-org/vfkit) (Apple
Virtualization framework) using [microvm.nix](https://github.com/microvm-nix/microvm.nix).

Based on <https://abhinavsarkar.net/notes/2026-microvm-nix/>.

### Additional References
- https://devctrl.blog/posts/maximum-security-confinement-for-your-ai-agents-with-microvm-nix/
- https://buduroiu.com/blog/openclaw-microvm/
- https://github.com/razvanz/nixbox
- https://kraftnix.dev/blog/why-you-should-use-microvm-nix/
- https://github.com/archie-judd/agent-sandbox.nix

## Why

The agent runs builds, tests, and other commands inside the VM. It cannot access
unshared host paths such as the Mac's `~/.ssh` or keychain. Guest root can access
the credentials provisioned to the VM and any files under the shared projects
directory. Networking is NAT-only, with the OpenCode port allowed through the
guest firewall for host attachment.

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
- The VM does not protect the shared repositories from the agent. Git helps
  recover ordinary edits, but the guest can also modify or delete `.git`.
  Keep an independent remote or backup for recovery.

A read-only share would be cosmetic anyway: vfkit's virtio-fs has no
host-side read-only flag, so `ro` could only be a guest mount option, which
guest root (the agent) can remount rw. Mounting rw states the real trust
model instead of implying a boundary that doesn't exist.

### Consequences worth knowing

- **Commit or stash before letting an agent loose**, and push or back up work
  that must survive loss of the shared checkout. Reflogs help only while the
  repository and its objects remain available.
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

- `vm.nix` configures the guest's vfkit runtime, storage, shares, and sandbox
  settings. It imports the selected host's portable `default.nix`.
- `hosts/darwin/<host>/default.nix` holds packages, shell configuration, and
  other settings shared by the Darwin host and its VM.
- `hosts/darwin/<host>/darwin.nix` holds macOS-only settings such as GUI apps,
  Homebrew, `launchd`, and system defaults.
- `darwin.nix` provides the host-side `microvm` lifecycle helper and opt-in
  Linux builder.

## Host configuration

Each enabled Darwin host has a matching NixOS output:

- `agent-sandbox-damascus`
- `agent-sandbox-MacBook-Pro-2`

Import `modules/microvm/darwin.nix` from a host's `darwin.nix` to install the
launchers. They build that host's matching guest. The guest logs in as `root`
and keeps its hostname as `agent-sandbox`, but receives the host's portable
packages, environment variables, shell settings, and development tools.

The guest excludes macOS-only configuration: GUI apps, Homebrew casks, `launchd`
settings, and macOS system defaults. Shared modules declare guest credentials
separately from the host's credentials.

## Building & running

Each VM is `aarch64-linux`. CI builds the enabled guest closures and pushes them
to Cachix, so you normally run:

```sh
microvm start        # start in the background
microvm status       # check the VM and OpenCode server
microvm logs         # follow the background console log
microvm stop
microvm restart      # stop and start again
microvm run          # foreground console
```

Run `microvm -h` for the command list. Exit a foreground VM with `poweroff` at
its shell prompt.

To (re)build a VM locally, temporarily set `microvm.linuxBuilder.enable = true`
in the host's `darwin.nix`, rebuild and switch, run `microvm run`, then set it
back to `false`.

State locations on the host (per-user, resolved at launch via `$HOME`):

- `~/.local/share/microvm/nix-store-overlay.img` — the VM's writable Nix store
  overlay (persists across runs).
- `~/.local/share/microvm/agent-state.img` — persistent agent state. The VM
  is otherwise stateless (tmpfs root; config comes from the Nix closure), but
  OpenCode sessions/history (`~/.local/share/opencode`) and the VM's gcloud
  configuration (`~/.config/gcloud`) are symlinked onto this volume so they
  survive `poweroff`.
  The guest's SOPS age identity persists at
  `/var/lib/agent-state/sops/age-key.txt`.
- `~/.local/share/microvm/dev-state.img` — persistent development scratch
  space and caches. It backs `TMPDIR`, `XDG_CACHE_HOME`, and Go's module and
  build caches, plus Docker images, containers, and volumes, so development
  workloads do not exhaust the tmpfs root.
- `~/.local/share/microvm/vfkit.pid` and `vfkit.log` — background process state
  and console output.
- `~/.local/share/microvm/runner` — GC root for the running VM closure.

Note: OpenCode's login state, gcloud's refresh credentials, and the SOPS age
identity live in persisted agent state. SOPS provisions the guest's API tokens
at runtime, including the GitHub token used by `gh` and Git-over-HTTPS. These
guest credentials are separate from the host's credential stores; the VM
boundary does not hide guest credentials from guest root.

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

From a directory below `~/projects`, run `opencode`. It starts the VM when
needed and attaches the host TUI to its OpenCode server with the corresponding
`/root/projects` directory. `opencode-vm` is an explicit alias for the same
remote behavior; use `opencode-local` to run OpenCode directly on macOS.

Keep the same directory open in your host editor: you see edits live, intervene
alongside the agent, and finished work is already in the host repo. Commit,
branch, and push with normal git habits. The Mac uses SSH for GitHub, while the
VM rewrites GitHub SSH URLs to HTTPS and uses the SOPS-managed `gh` token. Guest
pushes require the token's repository write permission; stored remotes and the
shared checkout remain unchanged.

Git signing is disabled in the VM; re-sign on the host if you need signed history.

See [credential management](../../notes/credentials.md) for authentication,
rotation, and recovery from old disks.
