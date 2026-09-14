# Damascus microVM bootstrap

This test has passed. The guest bootstrap declaration has been removed in favor
of the shared OpenAI API-key declaration. The procedure below records enrollment
for reference; it no longer describes the active application secret.

The Mac's user/admin and system identities have passed their decryption tests.
Their temporary bootstrap declarations and ciphertext have been removed; their
private key files and public recipient registrations stay in place.

Only the Damascus guest now declares `sops.secrets.bootstrap`, in
`modules/microvm/vm.nix`. It uses the guest's normal encrypted file,
`secrets/microvms/agent-sandbox-damascus.yaml`. The file now authorizes both
the personal/admin and enrolled guest recipients and contains a harmless test
value. The Mac, WSL, and work guest have no active bootstrap declaration.

## Next boot

The guest recipient is enrolled and the dummy value has been re-encrypted.
Rebuild the Mac, boot the guest, and run the service and dummy-value checks in
"Enroll and verify" below. The first-boot notes remain for reference.

## First boot

From the checkout on Damascus, rebuild the host so the launcher uses the new
guest configuration:

```sh
sudo darwin-rebuild switch --flake path:.#damascus
microvm stop
microvm run
```

`path:.` includes new files before they are committed. The launcher builds or
substitutes the guest closure; an uncached Linux build needs the Linux builder.
Use `microvm run` for this test, since the background launcher waits for OpenCode
to become healthy and would time out during enrollment.

If your current chat uses the guest server, keep a host-local OpenCode session
(`opencode-local`) available, or complete the recipient update from the Mac using
the commands below. The guest server cannot accept chats until decryption works.

On boot, the guest mounts its agent-state disk before activation. sops-nix
generates `/var/lib/agent-state/sops/age-key.txt` if it is missing, then decryption
fails because the new guest recipient is not enrolled yet. OpenCode should stay
down, but the root console should remain available. Existing guest keys are
reused; do not replace one just to exercise generation.

At the guest's root console, run:

```sh
age-keygen -y /var/lib/agent-state/sops/age-key.txt
```

Record this public `age1...` recipient, then run `poweroff` in the guest to return
to the Mac. Do not copy the private key into the repository or onto another VM.

## Enroll and verify

Add the guest public recipient as `&vm_damascus` under `keys` in `.sops.yaml`.
Change the guest file's recipient list to:

```yaml
key_groups:
  - age: [*admin_damascus, *vm_damascus]
```

From the Mac, using the personal/admin identity:

```bash
SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops updatekeys secrets/microvms/agent-sandbox-damascus.yaml
```

Alternatively, the same harmless value can be freshly encrypted to both public
recipients without reading any private key. Keep the Mac's machine recipient
out of the guest file; its admin recipient already provides recovery access.

After the ciphertext is updated, rebuild the host and run the guest in the
foreground again:

```sh
sudo darwin-rebuild switch --flake path:.#damascus
microvm run
```

At the guest console:

```sh
systemctl is-active sops-install-secrets.service opencode.service
cat /run/secrets/bootstrap
```

Both services should be active, and the file should contain:

```text
Non-sensitive Damascus microVM bootstrap test.
```

This content check is only for the harmless fixture. Finish with `poweroff`;
you can then use `microvm start` on the Mac to run the guest in the background.

Once the test passes, replace the guest's bootstrap declaration and YAML entry
with real application secrets. Keep the guest key on its persistent volume and
retain the enrolled public recipients. See [README.md](README.md) for shared
host/guest consumers and [home-manager.md](home-manager.md) for host-only user
credentials.
