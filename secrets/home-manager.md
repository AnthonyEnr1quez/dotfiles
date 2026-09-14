# Home Manager secrets

Real-machine configurations load both sops-nix modules. Use Home Manager for
user-level credentials and system-level sops-nix for machine credentials and
shared host/guest application configuration.

| Scope | Private identity | Default encrypted file |
| --- | --- | --- |
| Real-machine user | `$XDG_CONFIG_HOME/sops/age/keys.txt` (normally `~/.config/sops/age/keys.txt`) | `secrets/users/<host>/<username>.yaml` |
| Real-machine system | `/var/lib/sops-nix/key.txt` | `secrets/hosts/<host>.yaml` |
| MicroVM system | `/var/lib/agent-state/sops/age-key.txt` | `secrets/microvms/agent-sandbox-<host>.yaml` |

The Home Manager module is available to the configured users on `damascus`,
`MacBook-Pro-2`, and `mothership`. The VM constructors do not import it. Each user
has an independent key path and encrypted-file path.

## Admin and machine recipients

"Admin" describes which encrypted files you authorize a key to decrypt. Home
Manager does not grant that role itself. A typical recipient layout is:

- System files: your personal/admin recipient plus that machine's recipient.
- Guest files: your personal/admin recipient plus that guest's recipient.
- User files: the user's recipient and any chosen admin/recovery recipients.

Keep personal private keys on the real machines where you edit secrets. The VMs
need only their own machine identities. Adding a public recipient to `.sops.yaml`
affects new files; run `sops updatekeys <file>` for existing ciphertext.

## Add a user-level secret

Reuse or create your personal key as described in [the setup guide](README.md#2-create-or-reuse-your-personal-editing-key).
Home Manager uses this same key, and sets `SOPS_AGE_KEY_FILE` to its configured
path for the CLI. Empty user-secret configurations do not generate a key or start
the decryption service.

For Damascus's primary user, add this rule to `.sops.yaml`, using the existing
`&admin_damascus` public recipient:

```yaml
creation_rules:
  # Keep the existing host and guest rules too.
  - path_regex: ^secrets/users/damascus/ant\.yaml$
    key_groups:
      - age: [*admin_damascus]
```

From the repository root on the Mac:

```sh
mkdir -p secrets/users/damascus
sops secrets/users/damascus/ant.yaml
```

Enter a YAML string named `personal-mcp-token` in the editor. SOPS encrypts it
when you save. The other primary users' default files are:

- `secrets/users/MacBook-Pro-2/anthony.enriquez.yaml`
- `secrets/users/mothership/ant.yaml`

Use matching exact-path recipient rules for each file.

## Declare the consumer on the real machine

For a Mac-only credential, add the declaration to
`hosts/darwin/<host>/darwin.nix`. That file does not reach the guest. For WSL, use
`hosts/linux/mothership/default.nix`.

This example uses the repository's `hm` alias:

```nix
{ config, ... }:
let
  userSecrets = config.home-manager.users.${config.user.name}.sops.secrets;
in
{
  hm.sops.secrets.personal-mcp-token = { };

  hm.programs.opencode.settings.mcp.personal-service = {
    type = "remote";
    url = "https://mcp.example.com/mcp";
    oauth = false;
    headers.Authorization =
      "Bearer {file:${userSecrets.personal-mcp-token.path}}";
  };
}
```

Replace the URL and header with the MCP server's requirements. Pick a distinct
server name or provide a complete override for an existing generated MCP entry.

At system-module scope, `config.sops.secrets` refers to system secrets. Use
`config.home-manager.users.<user>.sops.secrets` to reference user secrets. Within
a Home Manager module, its own `config.sops.secrets` refers to the user secrets.
Home Manager secrets already belong to that user and have no `owner` option.

Keep `hm.sops` declarations out of `hosts/darwin/<host>/default.nix`: the VMs
inherit that file and intentionally have no Home Manager `sops` namespace.
Continue using system-level declarations there for shared host/guest consumers.

## Activation and updates

Track the encrypted file and configuration, then rebuild the real machine.
Home Manager reloads its secret service during activation:

- On macOS, a LaunchAgent decrypts as your user and runs at login.
- On Linux/WSL, `sops-nix.service` runs in your user systemd manager. You need an
  active user manager to run or restart it.

Applications reference stable paths under `~/.config/sops-nix/secrets` by default;
the module keeps decrypted generations in the platform's user runtime/temp
directory. Prefer `.path` references over hardcoding either location. Restart
OpenCode after updating secrets or its configuration so it reads the new values.

For a Linux user service consuming these secrets, order it after and require
`sops-nix.service`. System services should use system-level sops-nix instead.

## Automatic enrollment on another real machine

Both modules enable their own `sops.age.generateKey` option. They generate
different identities at different paths and reuse files that already exist.

To let Home Manager generate a new personal identity:

1. On an existing admin machine, encrypt the new user's file to an existing
   admin/recovery recipient and declare its user secrets.
2. Deploy on the new real machine and activate Home Manager in a user session.
   Its service generates the missing user key, then fails to decrypt until you
   enroll that identity. Depending on the platform, this failure may appear in
   the service logs rather than the rebuild's exit status.
3. On the new machine, print the public recipient as that user:

   ```bash
   age-keygen -y "$SOPS_AGE_KEY_FILE"
   ```

4. From the existing admin machine, add the recipient to the user's file rule,
   run `sops updatekeys <user-file>`, and redeploy. Also authorize it on host and
   guest files if it should serve as another admin key.

You can instead provision your existing personal key on the trusted machine.
Generation skips it, and it can decrypt files already addressed to that identity.
Machine-key enrollment remains the separate system-level process in
[the setup guide](README.md#5-first-deployment-and-machine-enrollment).

Inspect the macOS LaunchAgent's logs in `~/Library/Logs/SopsNix/`. On WSL, use
`systemctl --user status sops-nix.service`. These user services do not control
the VM's OpenCode startup dependencies.
