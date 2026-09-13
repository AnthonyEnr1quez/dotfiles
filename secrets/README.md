# Secrets

Use sops-nix with a separate age identity for each host and microVM. Keep your
personal editing/recovery identity on the host. Encrypt each machine's YAML to
that machine's public recipient and your personal public recipient.

The flake imports these declaration modules:

| Machine | Module and matching encrypted file |
| --- | --- |
| `damascus` | `secrets/hosts/damascus.{nix,yaml}` |
| `MacBook-Pro-2` | `secrets/hosts/MacBook-Pro-2.{nix,yaml}` |
| `mothership` | `secrets/hosts/mothership.{nix,yaml}` |
| Damascus guest | `secrets/microvms/agent-sandbox-damascus.{nix,yaml}` |
| Work guest | `secrets/microvms/agent-sandbox-MacBook-Pro-2.{nix,yaml}` |

Each `.nix` module starts empty. Add the encrypted YAML when you declare the first
secret. Empty configurations can build and boot before key enrollment.

## 1. Install the plumbing

Include the new files in Git before using a Git-backed flake. Review the files
you stage; only encrypted YAML and public recipients belong in the repository.
You can evaluate untracked files during development with `path:.`.

Rebuild the host with its normal command, for example:

```sh
sudo darwin-rebuild switch --flake .#damascus
# On WSL:
sudo nixos-rebuild switch --flake .#mothership
```

This installs `age`, `age-keygen`, and `sops`. Rebuild the Darwin host before
restarting its VM: the `microvm` launcher uses the flake snapshot from the host's
last rebuild.

## 2. Create or reuse your personal editing key

Run these examples in Bash on the host. Reuse your existing key if you already
have one at this path:

```bash
install -d -m 0700 "$HOME/.config/sops/age"
test -f "$HOME/.config/sops/age/keys.txt" || age-keygen -o "$HOME/.config/sops/age/keys.txt"
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
age-keygen -y "$SOPS_AGE_KEY_FILE"
```

The last command prints the public `age1...` recipient. New login shells get
`SOPS_AGE_KEY_FILE` from Home Manager, including on macOS. Back up the private
editing key in your password manager or another secure backup.

## 3. Bootstrap each machine's identity

### Hosts

Run on each host that will consume secrets:

```bash
sudo install -d -m 0700 /var/lib/sops-nix
sudo test -f /var/lib/sops-nix/key.txt || sudo "$(command -v age-keygen)" -o /var/lib/sops-nix/key.txt
sudo "$(command -v age-keygen)" -y /var/lib/sops-nix/key.txt
```

### MicroVMs

After installing the plumbing on the Mac, stop the background VM and open its
foreground console:

```sh
microvm stop
microvm run
```

At the guest's root console, run:

```sh
install -d -m 0700 /var/lib/agent-state/sops
test -f /var/lib/agent-state/sops/age-key.txt || age-keygen -o /var/lib/agent-state/sops/age-key.txt
age-keygen -y /var/lib/agent-state/sops/age-key.txt
```

Record the public recipient, then run `poweroff` in the guest to return to the
host. Repeat on the other Mac for its guest. Each VM keeps its private identity
on its own `agent-state.img`; deleting that image requires restoring the key or
enrolling a new one. Keep the key file at mode `0600`.

The guest uses systemd-based secret provisioning. sops-nix requires the mount
containing the age key before decryption, and OpenCode requires successful
provisioning once you declare regular secrets. Use ordinary runtime secrets in
these guests; `neededForUsers` runs earlier and needs separate early-boot key
mounting.

## 4. Enroll public recipients

Replace the empty lists in `.sops.yaml` with your public recipients and exact
file rules. For example, after substituting real `age1...` values:

```yaml
keys:
  - &admin age1REPLACE_WITH_PERSONAL_PUBLIC_RECIPIENT
  - &damascus age1REPLACE_WITH_HOST_PUBLIC_RECIPIENT
  - &vm_damascus age1REPLACE_WITH_GUEST_PUBLIC_RECIPIENT

creation_rules:
  - path_regex: ^secrets/hosts/damascus\.yaml$
    key_groups:
      - age: [*admin, *damascus]
  - path_regex: ^secrets/microvms/agent-sandbox-damascus\.yaml$
    key_groups:
      - age: [*admin, *vm_damascus]
```

Add matching rules for `MacBook-Pro-2`, `mothership`, and the work guest as you
enroll them. A recipient can decrypt the whole YAML file, so keep host-only
credentials out of guest files.

## 5. Add static OpenCode credentials

From the repository root on your host, open the guest's encrypted file:

```sh
sops secrets/microvms/agent-sandbox-damascus.yaml
```

Enter your credentials in the editor, for example an `anthropic-api-key` YAML
string. SOPS encrypts the values when you save. Then edit the matching `.nix`
module:

```nix
{ config, ... }:
{
  sops.secrets.anthropic-api-key = {
    restartUnits = [ "opencode.service" ];
  };

  hm.programs.opencode.settings.provider.anthropic.options.apiKey =
    "{file:${config.sops.secrets.anthropic-api-key.path}}";
}
```

OpenCode reads `/run/secrets/anthropic-api-key` at startup. Nix stores the file
reference in its generated configuration. Use `.path` and OpenCode's `{file:...}`
syntax rather than reading plaintext with `builtins.readFile`.

### Remote MCP tokens

Add `remote-mcp-token` to the encrypted YAML, declare it under `sops.secrets` with
the same `restartUnits`, and add the consumer in that machine's module:

```nix
hm.programs.opencode.settings.mcp.example = {
  type = "remote";
  url = "https://mcp.example.com/mcp";
  oauth = false;
  headers.Authorization =
    "Bearer {file:${config.sops.secrets.remote-mcp-token.path}}";
};
```

Replace the example URL and authentication header with the server's requirements.
For servers already declared by `hm.programs.mcp`, an entry in
`hm.programs.opencode.settings.mcp.<name>` replaces the entire generated server
entry. Include its `type`, `url` (or `command`), credentials, and `enabled = true`
when enabling it for OpenCode.

### Local MCP tokens

After declaring `local-mcp-token`, pass its value to the child process:

```nix
hm.programs.opencode.settings.mcp.example = {
  type = "local";
  command = [ "example-mcp-server" ];
  environment.API_TOKEN =
    "{file:${config.sops.secrets.local-mcp-token.path}}";
};
```

Install the actual MCP command and use the environment variable it expects.

### Credentials required in the OpenCode server environment

For software that needs an environment variable on the server itself, encrypt
an environment file as a YAML multiline string named `opencode-env`. Declare it
as a secret with `restartUnits = [ "opencode.service" ]`, then set:

```nix
systemd.services.opencode.serviceConfig.EnvironmentFile =
  config.sops.secrets.opencode-env.path;
```

Use systemd environment-file syntax such as `API_TOKEN=value`. The service does
not load your interactive shell's environment.

### Host applications

Declare host secrets in `secrets/hosts/<host>.nix` and use the same `.path`
references. For applications running as your primary user, set
`owner = config.user.name` on the secret. NixOS supports `restartUnits`;
nix-darwin requires you to restart the consuming application after updating its
credentials.

### OAuth and interactive logins

Log in from the guest and let OpenCode update its writable authentication state.
The VM already persists `/root/.local/share/opencode` on the agent-state volume.
Keep refreshed OAuth state there rather than managing it as static SOPS data.

## 6. Deploy and update

Track the encrypted YAML and declaration changes, then rebuild the relevant host.
For a Mac and its guest:

```sh
sudo darwin-rebuild switch --flake .#damascus
microvm restart
```

The launcher builds/substitutes the new guest configuration. CI can build it
without private keys; decryption happens inside the guest. OpenCode loads file
references when it starts, so restart it after changing credential references.
During an in-guest NixOS switch, sops-nix restarts the units listed in
`restartUnits` when it installs changed secrets.

Inspect provisioning from the guest console without printing secret values:

```sh
systemctl status sops-install-secrets.service opencode.service
stat -c '%a %U %n' /var/lib/agent-state/sops/age-key.txt
```

The provisioning unit exists after you declare the first regular secret. If
decryption fails, check the enrolled public recipient and the persisted key.

After changing recipients in `.sops.yaml`, update existing ciphertext:

```sh
sops updatekeys secrets/microvms/agent-sandbox-damascus.yaml
```

Then deploy the changed file. Removing a recipient does not revoke its access to
older encrypted copies. Rotate the underlying tokens if you lose control of a
machine or its identity. Guest root, including the agent, can access the guest's
keys and credentials; the OpenCode file-tool rules only help prevent accidental
reads.
