# Credentials

SOPS encrypts credentials in Git; sops-nix decrypts them on the target machine.
Keep private age keys outside the repository and Nix store. CI builds need only
the encrypted files, not decryption keys. Shell examples below use Bash.

## Identities and files

| Scope | Private identity | Encrypted file |
| --- | --- | --- |
| Real-machine user/admin | `~/.config/sops/age/keys.txt` | `secrets/users/<host>/<user>.yaml` |
| Real-machine system | `/var/lib/sops-nix/key.txt` | `secrets/hosts/<host>.yaml` |
| MicroVM system | `/var/lib/agent-state/sops/age-key.txt` | `secrets/microvms/agent-sandbox-<host>.yaml` |

The user key defaults to `$XDG_CONFIG_HOME/sops/age/keys.txt` and also serves the
SOPS CLI through `SOPS_AGE_KEY_FILE`. It is an admin/recovery identity only for
files that include its public recipient. Keep personal and work recipients
separate unless you deliberately grant cross-machine access.

System files normally authorize the matching admin and machine recipients. User
files authorize the user and any chosen recovery recipients. `.sops.yaml` records
these public recipients and exact-path creation rules. A recipient can decrypt
the entire file, not just the entries declared in Nix.

Real machines support both system-level and Home Manager sops-nix. Guests use
only system-level provisioning and never receive the admin private key. Their
age key lives on the agent-state disk, which mounts before activation.

## Declarations and consumers

| Configuration | Purpose |
| --- | --- |
| `hosts/darwin/shared.nix` | OpenAI, Anthropic, and GitHub secrets for both Mac/VM pairs |
| `hosts/darwin/<host>/default.nix` | Declarations shared by one Mac and its guest |
| `hosts/darwin/<host>/darwin.nix` | Mac-only system or `hm.sops` declarations |
| `modules/home-manager/ai/opencode/default.nix` | Provider API-key references |
| `modules/home-manager/ai/mcp.nix` | Native OpenCode MCP configuration |

All four Mac/guest files currently require `openai-api-key`, `anthropic-api-key`,
and `github-token`. The work pair also declares `honeycomb-api-key`,
`linear-api-key`, and `postman-api-key`.

Add a system secret alongside its consumer's configuration, for example:

```nix
sops.secrets.service-token.owner = config.user.name;
```

Use the resulting `.path` at runtime, never `builtins.readFile` on the decrypted
file. In a Home Manager module, `config.sops` means user secrets and
`osConfig.sops` means system secrets. Keep `hm.sops` declarations out of modules
imported by guests, which do not have that user-level module.

OpenCode uses `{file:...}` references when a matching system secret is declared.
The encrypted file is not scanned to discover features. Missing required files
or entries are configuration errors, not optional credentials.

MCP servers use API-key Bearer headers with OAuth disabled. Honeycomb requires a
management key in `KEY_ID:KEY_SECRET` form with MCP and Environments permissions.
Honeycomb and Postman currently use US endpoints; change their URLs for EU
accounts. Leave refreshed OAuth/login state under the application's own state
management rather than overwriting it with static SOPS data.

## Edit and deploy

Edit from the appropriate Mac using its admin identity, not from a guest with
only a machine key. From the checkout:

```bash
host=damascus # or MacBook-Pro-2
sops "secrets/hosts/$host.yaml"
sops "secrets/microvms/agent-sandbox-$host.yaml"
sudo darwin-rebuild switch --flake "path:.#$host"
microvm restart
```

Enter values in the SOPS editor; it encrypts them on save. Preserve unrelated
entries. `path:.` includes new files during development; stage encrypted files
before using a Git-backed flake or committing. User-level files use
`secrets/users/<host>/<user>.yaml` and need their own recipient rule.

Rebuilding the Mac updates the launcher's guest configuration snapshot. Restart
host-local OpenCode too when provider/MCP configuration or values change. Guest
secrets default to restarting `opencode.service` during an in-guest switch;
override a secret's `restartUnits` list if it has another consumer.

Use `systemctl status sops-install-secrets.service opencode.service` in the guest
to check provisioning. `active (exited)` is normal for the oneshot SOPS service.
Do not use `opencode debug config` to inspect credentials: it prints their
resolved values. Removing the last secret declaration can disable provisioning
without a final cleanup pass, leaving old decrypted files or symlinks behind.

## New or replacement identities

Prefer restoring an existing authorized identity from a secure backup when
replacing a machine. Generating a new key does not grant access to existing
ciphertext.

For a new identity:

1. Prepare the required encrypted files using an existing admin recipient and
   add the matching Nix declarations. Files must exist before evaluation; use a
   non-sensitive temporary secret if the goal is only to bootstrap a key.
2. Deploy. Native `sops.age.generateKey` creates a missing key once secrets are
   declared, then decryption fails until the new recipient is enrolled. Empty
   secret configurations do not generate keys. Home Manager follows the same
   rule for user secrets and needs an active user session.
3. Retrieve the public recipient with `age-keygen -y` on the identity's path.
   Use `sudo` for the system key on a Mac. For a new guest, use `microvm run` and
   its root console; background startup waits for OpenCode health and will time
   out while decryption fails. Keep a host-local session available during this.
4. Add the public recipient to the appropriate rule in `.sops.yaml`. From a
   machine with an existing authorized admin key, run `sops updatekeys <file>`
   for each affected file. Changing the creation rule alone does not update
   existing ciphertext. A disposable fixture can instead be recreated from its
   known dummy value using only the new public recipients.
5. Redeploy, verify decryption, and remove any temporary bootstrap declarations
   and data. Back up the new admin identity securely.

For the first-ever admin identity, create it with `age-keygen` outside the
repository before encrypting the initial files. Do not overwrite an identity
that belongs to another project; use a separate path and update that project's
key selection if needed.

## GitHub

SOPS renders `github-token` into a mode-`0400` `gh` account file outside the Nix
store. Home Manager links it at `~/.config/gh/hosts.yml`, replacing previous
account entries. Non-secret settings remain in `gh/config.yml`. Use SOPS for
rotation, not imperative `gh auth login`, `logout`, `refresh`, or `switch`.

Macs use SSH for GitHub Git operations; guests rewrite the two common GitHub SSH
URL forms to HTTPS and use `gh`'s credential helper. Stored remotes and the shared
projects directory are unchanged. Non-GitHub URLs and custom SSH aliases are not
rewritten. Guest commit signing is disabled.

Use separate scoped tokens, especially for guests. Limit repository selection
and permissions to needed operations; fetching needs read access and pushing
needs write access. Fine-grained tokens have one resource owner and may need
organization approval.

Verify the account and transport without printing credentials:

```sh
gh api user --jq .login
git remote -v
```

Inside a guest, test a private repository authorized for its token:

```sh
GIT_SSH_COMMAND=false git ls-remote origin HEAD
```

`GH_TOKEN` and `GITHUB_TOKEN` override the managed file. Clear stale environment
overrides when testing. Account labels in `gh auth status` may be empty because
the managed file does not hardcode a username; the API check above identifies it.

## Rotation and recovery

For routine token rotation, create a replacement, edit the target ciphertext,
deploy, verify access, then revoke the old token. For suspected compromise,
revoke access first and investigate before restoring service.

For identity rotation, enroll the replacement recipient, update the affected
files with an authorized key, and deploy before removing the old recipient.
Update ciphertext again after removal. Old Git history and disk backups still
contain older copies; removing a recipient cannot revoke access to those copies.
Rotate underlying credentials if a decryption key was exposed.
