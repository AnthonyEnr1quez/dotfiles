# Agent sandbox microVMs

Host-specific NixOS guests on Apple Silicon macOS, using
[microvm.nix](https://github.com/microvm-nix/microvm.nix) and
[vfkit](https://github.com/crc-org/vfkit).
Based on <https://abhinavsarkar.net/notes/2026-microvm-nix/>.

### Additional References
- https://devctrl.blog/posts/maximum-security-confinement-for-your-ai-agents-with-microvm-nix/
- https://buduroiu.com/blog/openclaw-microvm/
- https://github.com/razvanz/nixbox
- https://kraftnix.dev/blog/why-you-should-use-microvm-nix/
- https://github.com/archie-judd/agent-sandbox.nix

## Configuration

- `vm.nix`: Linux guest, storage, shares, and OpenCode service.
- `darwin.nix`: host launcher and optional Linux builder.
- `hosts/darwin/<host>/default.nix`: portable settings shared with the guest.
- `hosts/darwin/<host>/darwin.nix`: macOS-only settings and launcher import.
- `profiles/secrets.nix`: shared host credentials; the guest excludes this module.

Each Mac selects its matching `agent-sandbox-damascus` or
`agent-sandbox-MacBook-Pro-2` output. The guest runs as root with 4 vCPUs and
8 GiB RAM. CI caches the Linux closures; the launcher builds/substitutes its
runner on demand rather than during every Darwin rebuild.

## Use

Run `opencode` inside `~/projects` to start the VM and attach to the matching
guest directory. `opencode-vm` does the same; `opencode-local` uses the host's
credential-aware executable. Host and guest edits affect the same working copy.

```sh
microvm start        # background; wait up to 120 seconds for OpenCode
microvm run          # foreground console; exit with guest poweroff
microvm stop         # graceful shutdown; wait up to 120 seconds
microvm restart
microvm status       # exit 0: ready, 1: stopped, 2: starting/unhealthy
microvm address      # running guest's IPv4 address
microvm logs
```

The launch lock covers builds, execution, and cleanup. Concurrent starts wait
for the same VM. Startup timeout includes build time and leaves the launch
running; inspect logs or retry. `stop` cannot cancel an in-progress build and
does not force termination on timeout. An older runner without `control.sock`
needs a one-time guest `poweroff` before using the new launcher.

The launcher finds MAC `02:00:00:01:01:01` in `/var/db/dhcpd_leases`.
Set `MICROVM_GUEST_ADDRESS` to the actual guest IPv4 address if discovery fails.
It prefers `~/projects`, falling back to `~/Projects`. The canonical share root
and host state path support ASCII letters, digits, `/`, `.`, `_`, and `-` due
to upstream argument splitting. Nested project names may contain spaces.

For local Linux builds, set `microvm.linuxBuilder.enable = true` in the host's
`darwin.nix` and rebuild. This uses nix-darwin's stock cached builder. Allow RAM
for both VMs; disabling the builder deletes its disk/cache.

## Credentials

Provision the existing age private key from a secure backup at
`~/.config/sops/age/keys.txt` (mode `0600`, parent directories `0700`). Do not
overwrite an existing key or replace it with one that cannot decrypt the bundles.
The launcher also accepts `SOPS_AGE_KEY_FILE`.

Host Home Manager decrypts `personal.sops.yaml`. At VM launch, the host decrypts
only `secrets/agent.sops.env` into a private temporary directory and shares it as
`/run/host-secrets`. The guest service reads `opencode.env`; the age key stays on
the host. Decryption failure aborts launch. Without the bundle, the VM can boot
for diagnostics but OpenCode cannot start.

Rotate from a trusted host editor:

```sh
sops edit --input-type dotenv --output-type dotenv secrets/agent.sops.env
git add -- secrets/agent.sops.env
sudo darwin-rebuild switch --flake .#damascus  # or .#MacBook-Pro-2
microvm restart
```

Verify the new credentials, then revoke the old ones. The launcher pins the
installed flake snapshot, so editing ciphertext and restarting alone is not
enough. Track ciphertext, never private keys or plaintext.

## State and shares

Host state lives under `~/.local/share/microvm` (directory `0700`, images/logs
`0600`). The guest has a tmpfs root with three persistent sparse images:

| Image | Size cap | Contents |
| ----- | -------- | -------- |
| `nix-store-overlay.img` | 40 GiB | Writable store and `/nix/var/nix` database, profiles, GC roots |
| `agent-state.img` | 10 GiB | OpenCode sessions/auth, gcloud credentials, VM-specific GitHub SSH identity |
| `dev-state.img` | 40 GiB | Build scratch, Go/tool caches, Docker data |

The initrd binds Nix state before activation; each boot registers the system
closure. Existing overlay contents remain intact, but previously unregistered
paths are not repaired. Guest GC roots do not protect shared paths from host GC;
the host `runner` symlink roots the declared VM closure.

The guest mounts projects read-write and reads the host Nix store as its overlay
lower layer. OpenCode requires both projects and credentials mounts plus successful
Home Manager activation. The launcher removes its `agent-secrets.XXXXXX` directory
after normal shutdown. After a crash, verify no VM/launch uses a stale directory
before removing that specific directory; do not use wildcard deletion.

## Trust boundary

- Guest code can modify all shared projects, including `.git`. Keep a remote or
  backup the guest cannot modify; reflogs are not a backup against `.git` deletion.
- Shared hooks, Git config, and build scripts can execute on the host later.
  Review changes before running host commands or rebuilding these dotfiles.
- Guest-root code can read supplied API tokens and persisted credentials.
  OpenCode read guards prevent accidents, not access by shell/dependency code.
- NAT allows outbound traffic and access to reachable host/LAN services.
  OpenCode remains unauthenticated on `0.0.0.0:4096`; anyone who can reach it may
  control the agent. Authentication remains deferred.
- Host SSH keys, keychains, and other unshared paths stay outside the VM. The
  guest can read the entire host Nix store; host permissions protect store writes.

Use Nix evaluation and ShellCheck for configuration/static checks. Verify native
vfkit shutdown, mounts, and reboot persistence on macOS after deployment.
