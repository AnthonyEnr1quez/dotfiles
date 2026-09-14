# Secrets

Use sops-nix with a separate age identity for each host and microVM. Keep your
personal editing/recovery identity on the host. Encrypt each machine's YAML to
that machine's public recipient and your personal public recipient.

Keep application secret declarations and their Home Manager consumers in the
existing host modules. Each microVM imports `hosts/darwin/<host>/default.nix`, so
one declaration configures both the Mac and its guest. Nix evaluates the module
with each machine's own `config`, primary user, and SOPS settings.

| Machine | Encrypted file |
| --- | --- |
| `damascus` | `secrets/hosts/damascus.yaml` |
| `MacBook-Pro-2` | `secrets/hosts/MacBook-Pro-2.yaml` |
| `mothership` | `secrets/hosts/mothership.yaml` |
| Damascus guest | `secrets/microvms/agent-sandbox-damascus.yaml` |
| Work guest | `secrets/microvms/agent-sandbox-MacBook-Pro-2.yaml` |

Put Mac/guest shared declarations in `hosts/darwin/<host>/default.nix`, Mac-only
declarations in `hosts/darwin/<host>/darwin.nix`, and WSL declarations in
`hosts/linux/mothership/default.nix`. Guest-only configuration belongs in a module
imported by `modules/microvm/vm.nix`; use its `host` argument for per-guest choices.

Both machines need the same YAML keys for shared declarations, but can use
different credential values. Add their encrypted files before deploying the
declarations. Configurations without declared secrets can build and boot before
key enrollment.

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

From the repository root on your host, open both encrypted files for the pair:

```sh
sops secrets/hosts/damascus.yaml
sops secrets/microvms/agent-sandbox-damascus.yaml
```

Enter an `anthropic-api-key` YAML string in each file, using the credential for
that machine. SOPS encrypts the values when you save. Add the declaration and
consumer to `hosts/darwin/damascus/default.nix`:

```nix
{ config, ... }:
{
  sops.secrets.anthropic-api-key.owner = config.user.name;

  hm.programs.opencode.settings.provider.anthropic.options.apiKey =
    "{file:${config.sops.secrets.anthropic-api-key.path}}";
}
```

OpenCode reads `/run/secrets/anthropic-api-key` at startup on each machine. The
owner resolves to your user on the Mac and `root` in the VM. Nix stores the file
reference in its generated configuration. Use `.path` and OpenCode's `{file:...}`
syntax rather than reading plaintext with `builtins.readFile`.

The VM defaults `restartUnits` to `[ "opencode.service" ]` for regular secrets.
Keep this Linux-only option out of shared Mac/guest declarations. To opt out or
choose other consumers, override the list in guest-only configuration:

```nix
sops.secrets.some-other-secret.restartUnits = [ ];
```

An explicit list replaces the default; include `"opencode.service"` if it should
restart alongside another service. Early `neededForUsers` secrets get no default
restart units. Restart host applications yourself after changing their secrets.

### Remote MCP tokens

Add `remote-mcp-token` to both encrypted YAML files and add this declaration and
consumer to the shared host module:

```nix
sops.secrets.remote-mcp-token.owner = config.user.name;

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

Add `local-mcp-token` to both encrypted YAML files, then declare it and pass its
value to the child process in the shared host module:

```nix
sops.secrets.local-mcp-token.owner = config.user.name;

hm.programs.opencode.settings.mcp.example = {
  type = "local";
  command = [ "example-mcp-server" ];
  environment.API_TOKEN =
    "{file:${config.sops.secrets.local-mcp-token.path}}";
};
```

Install the actual MCP command and use the environment variable it expects.

### Credentials required in the OpenCode server environment

For software that needs an environment variable on the guest server itself,
encrypt an environment file as a YAML multiline string named `opencode-env` in
the guest YAML. Add the following in guest-only configuration:

```nix
sops.secrets.opencode-env = { };

systemd.services.opencode.serviceConfig.EnvironmentFile =
  config.sops.secrets.opencode-env.path;
```

Use systemd environment-file syntax such as `API_TOKEN=value`. The service does
not load your interactive shell's environment.

### Host applications

For Mac-only applications, declare secrets in `hosts/darwin/<host>/darwin.nix`
and use the same `.path` references. For applications running as your primary
user, set `owner = config.user.name` on the secret. On WSL, use
`hosts/linux/mothership/default.nix` and set any needed service `restartUnits`
there; only the OpenCode microVMs get automatic restart defaults.

### OAuth and interactive logins

Log in from the guest and let OpenCode update its writable authentication state.
The VM already persists `/root/.local/share/opencode` on the agent-state volume.
Keep refreshed OAuth state there rather than managing it as static SOPS data.

## 6. Deploy and update

Track the encrypted YAML files and shared host-module changes, then rebuild the
relevant host.
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
