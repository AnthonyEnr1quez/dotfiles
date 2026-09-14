# Work Mac enrollment handoff

## Session start prompt
Read notes/work-mac-enrollment.md and help me enroll this Mac and its microVM.

Use this guide in a new OpenCode session on the work Mac. The Damascus Mac and
its microVM have passed their bootstrap tests. Repeat that sequence for
`MacBook-Pro-2`; do not redesign the secret-manager setup.

This guide lives outside `secrets/` so the session can read it without changing
the agent's credential-read permissions.

## Context for the next session

- Real machines use both system-level and Home Manager sops-nix.
- Home Manager's personal key serves as an admin/recovery identity only for the
  files whose recipient rules authorize it. System-level keys identify machines.
- MicroVMs use system-level sops-nix only. Never provision an admin private key
  into a guest or add the Home Manager sops module to its configuration.
- Both modules enable native `sops.age.generateKey`. They generate a missing key
  only when at least one secret is declared, and reuse existing keys.
- We accept two-pass enrollment: the first activation generates a key and fails
  to decrypt; after adding the public recipient, the next activation succeeds.
- No custom key-generation scripts or SSH-key conversion are needed.
- The VM's agent-state volume is already marked `neededForBoot`, so the native
  generation hook writes to persistent storage. Decryption runs later via systemd.
- Shared Mac/guest application configuration lives in
  `hosts/darwin/<host>/default.nix`. Mac-only configuration, including `hm.sops`
  declarations, belongs in `hosts/darwin/<host>/darwin.nix`.

Damascus's public recipients are recorded in `.sops.yaml` as `admin_damascus`,
`damascus`, and `vm_damascus`. Preserve them and their rules. Do not copy their
private identities to the work machines.

Damascus's bootstrap declarations have been removed after successful tests. Its
shared host module now declares an OpenAI API-key secret. Inspect the current
worktree before editing: it may contain staged or unstaged user changes to the
lock file, Linux builder, launcher, or other configuration. Do not undo those.

## Target paths

| Item | Work Mac / guest value |
| --- | --- |
| Darwin output | `darwinConfigurations.MacBook-Pro-2` |
| Primary user | `anthony.enriquez` |
| Mac-only module | `hosts/darwin/MacBook-Pro-2/darwin.nix` |
| User/admin key | `/Users/anthony.enriquez/.config/sops/age/keys.txt` |
| Machine key | `/var/lib/sops-nix/key.txt` |
| Guest output | `nixosConfigurations.agent-sandbox-MacBook-Pro-2` |
| Guest key | `/var/lib/agent-state/sops/age-key.txt` |
| Normal system ciphertext | `secrets/hosts/MacBook-Pro-2.yaml` |
| Normal user ciphertext | `secrets/users/MacBook-Pro-2/anthony.enriquez.yaml` |
| Guest ciphertext | `secrets/microvms/agent-sandbox-MacBook-Pro-2.yaml` |

## 1. Preflight

On the Mac, confirm the logged-in account matches the configured primary user.
Use the checkout containing this configuration. Commands below use `path:.` so
new files are visible to Nix even before they are staged or committed.

Ask whether the user/admin and machine keys already exist. Do not display private
key contents. If a key is already dedicated to this setup, reuse it. If the user
key belongs to another project, let the user move it to a project-specific path
and update that project's tooling before generating a new one at the default
path. Do not overwrite or delete an existing identity to force a generation test.

The first test needs no real API credentials and no old project private key.
The agent can encrypt a known dummy value using public recipients alone.

## 2. Bootstrap the Mac's two identities

Have the agent prepare a temporary ciphertext at
`secrets/bootstrap-work-mac.yaml` containing this known, non-sensitive value:

```yaml
bootstrap: Non-sensitive work Mac bootstrap test.
```

Initially, encrypt it to the existing `admin_damascus` public recipient. This
authorizes access only to the harmless dummy value, not future work credentials.
Add an exact temporary creation rule to the existing `.sops.yaml` rule list:

```yaml
- path_regex: ^secrets/bootstrap-work-mac\.yaml$
  key_groups:
    - age: [*admin_damascus]
```

For example, after creating `notes/.work-bootstrap-plaintext.yaml` with the dummy
value, the agent can encrypt it without any private key:

```sh
nix shell --inputs-from path:. nixpkgs#sops --command sops --encrypt --filename-override secrets/bootstrap-work-mac.yaml --output secrets/bootstrap-work-mac.yaml notes/.work-bootstrap-plaintext.yaml
```

Remove the temporary plaintext file afterwards. Use real SOPS encryption, not
handwritten placeholder ciphertext; the Nix build validates encrypted files.

Add these temporary declarations to the Mac-only module, merging with its
existing configuration:

```nix
sops.secrets.bootstrap.sopsFile = ../../../secrets/bootstrap-work-mac.yaml;
hm.sops.secrets.bootstrap.sopsFile = ../../../secrets/bootstrap-work-mac.yaml;
```

On the Mac, in the logged-in user session:

```sh
sudo darwin-rebuild switch --flake path:.#MacBook-Pro-2
```

Expect a decryption failure from the new identities. A build/evaluation failure
is different: it may mean activation and generation never ran. Home Manager
activation precedes system-level secret setup, and its LaunchAgent starts
asynchronously. If the user key is not there immediately, wait briefly and retry;
check `~/Library/Logs/SopsNix/` if it remains missing.

Ask the user to run these separately after the rebuild returns, even if it exited
with a decryption error:

```sh
age-keygen -y "$HOME/.config/sops/age/keys.txt"
sudo age-keygen -y /var/lib/sops-nix/key.txt
```

Collect only the public `age1...` recipients, labeled user/admin and machine.
Register them as `admin_work` and `work_mac` in `.sops.yaml`. Update the temporary
rule to `[ *admin_work, *work_mac ]` and freshly encrypt the same dummy value to
those recipients. No old private key or `sops updatekeys` is necessary when
replacing a known dummy value.

Repeat the Darwin switch. Then ask the user to verify both provisioning layers:

```sh
cat "$HOME/.config/sops-nix/secrets/bootstrap"
sudo cat /run/secrets/bootstrap
```

Both should print `Non-sensitive work Mac bootstrap test.` These content checks
are only for the dummy fixture. Once confirmed, remove the Mac's two temporary
declarations, temporary ciphertext, and temporary recipient rule. Keep both
identities and their public registrations.

## 3. Bootstrap the work guest

Use the guest's normal ciphertext path from the table. Add an exact rule for
`^secrets/microvms/agent-sandbox-MacBook-Pro-2\.yaml$`, initially authorizing only
`admin_work`. Encrypt this known value to that public recipient:

```yaml
bootstrap: Non-sensitive work microVM bootstrap test.
```

Declare the guest bootstrap only for the work guest in `modules/microvm/vm.nix`.
If the existing Damascus bootstrap declaration is still present, extend its
condition rather than defining `sops.secrets.bootstrap` twice:

```nix
sops.secrets.bootstrap = lib.mkIf (builtins.elem host [
  "damascus"
  "MacBook-Pro-2"
]) { };
```

If Damascus's fixture has already been removed, use only `host == "MacBook-Pro-2"`.
Do not enable a secret for a guest without its matching encrypted file. The
existing defaultSopsFile wiring selects each guest's own YAML, and regular guest
secrets already default to restarting `opencode.service` when updated.

On the Mac:

```sh
sudo darwin-rebuild switch --flake path:.#MacBook-Pro-2
microvm stop
microvm run
```

Rebuilding the host matters: its launcher uses the flake snapshot from the last
host rebuild. Uncached guest builds need an aarch64-linux builder. Check the
existing `microvm.linuxBuilder.enable` setting if building fails; do not change
unrelated builder settings as part of enrollment.

Use foreground `microvm run`, not `start`, for initial enrollment. The background
launcher waits for OpenCode health and would time out because OpenCode requires
successful secret decryption. If this chat runs in the guest, use `opencode-local`
on the Mac or complete enrollment from the host while the guest server is down.

At the guest root console:

```sh
age-keygen -y /var/lib/agent-state/sops/age-key.txt
```

Collect that public recipient as `work_vm`, then run `poweroff` in the guest.
Register the recipient in `.sops.yaml` and change the work guest's rule to
`[ *admin_work, *work_vm ]`. Freshly encrypt the known dummy value to both keys.
The Mac's machine key does not need access to the guest's file.

Rebuild the host again and run `microvm run`. In the guest, verify:

```sh
systemctl is-active sops-install-secrets.service opencode.service
cat /run/secrets/bootstrap
```

Both services should report `active`; the file should contain
`Non-sensitive work microVM bootstrap test.` If checked very early, retry after
a few seconds. On Damascus, decryption finished before OpenCode started, so an
early status check looked unsuccessful even though startup completed normally.

`active (exited)` is correct for the oneshot sops service. OpenCode should be
`active (running)`. Use this command for details:

```sh
systemctl status sops-install-secrets.service opencode.service --no-pager --full
```

Finish with `poweroff`, then `microvm start` on the Mac for background operation.

## 4. Finish and add real credentials

After both Mac scopes and the guest pass, remove the work guest's temporary
bootstrap declaration and replace the dummy YAML entry with real declarations
and credentials, or remove the dummy file until needed. Preserve any active
Damascus declarations when editing the shared guest module. Old decrypted dummy
files may remain after removing declarations; do not confuse those with active
provisioning and do not delete the private identities.

The intended work-machine recipient rules are:

| File | Recipients |
| --- | --- |
| `secrets/hosts/MacBook-Pro-2.yaml` | `admin_work`, `work_mac` |
| `secrets/users/MacBook-Pro-2/anthony.enriquez.yaml` | `admin_work` |
| `secrets/microvms/agent-sandbox-MacBook-Pro-2.yaml` | `admin_work`, `work_vm` |

Do not automatically grant the personal Mac's admin key access to real work
credentials. Confirm any cross-machine admin/recovery access with the user.
Back up the personal/admin identity securely; keep VM keys on their persistent
agent-state disks. Real secret values should be entered locally through SOPS,
not pasted into the chat.

Use system-level declarations in the shared host module for credentials consumed
by both the Mac and guest. Use `hm.sops` in the Mac-only module for user-only
credentials. Each provisioning layer has its own `config.sops.secrets` namespace.
Ask which providers/MCP servers need credentials before adding consumers.

Run formatting and `nix flake check --no-build path:.`, evaluate both Darwin
configurations explicitly, and build the work guest's
`config.system.build.sops-nix-manifest` on Linux when available. Check that the
other machines have not gained unintended declarations. Do not commit, push, or
restart the current session's server unless requested.
