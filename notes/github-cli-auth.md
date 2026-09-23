# GitHub CLI and Git authentication

Each Mac and guest declares `github-token` in its own encrypted YAML. SOPS
renders a `gh` credentials file outside the Nix store. Home Manager links it at
`~/.config/gh/hosts.yml` and replaces any previous file there. SOPS is the source
of truth for that file; this replaces its previous account entries, not just one
token. Other machines' logins and the macOS keychain are not modified.

| Environment | GitHub Git transport | Credentials |
| --- | --- | --- |
| Mac | SSH | Existing Mac SSH key for Git; SOPS token for `gh` API calls |
| MicroVM | HTTPS | SOPS token for both Git and `gh` API calls |

No repository remote is edited. The VM rewrites `git@github.com:...` and
`ssh://git@github.com/...` URLs to HTTPS, while the Macs retain the opposite
HTTPS-to-SSH rewrite. The shared projects mount and stored `.git/config` values
stay unchanged. Non-GitHub hosts and custom SSH host aliases are unaffected.

## Provision tokens

Create separate GitHub tokens for the machines, especially the VMs. Prefer
fine-grained tokens restricted to the repositories and operations each needs.
Read-only Contents access is enough for fetch/clone; pushing requires write
access. Add Pull Requests, Issues, Actions, and other permissions only as needed.
Organization policy may require approval. Fine-grained tokens have one resource
owner, so one token will not cover arbitrary repositories across different
organizations and personal accounts.

On Damascus, using its personal/admin age identity:

```sh
sops secrets/hosts/damascus.yaml
sops secrets/microvms/agent-sandbox-damascus.yaml
```

On the work Mac, using its own personal/admin identity:

```sh
sops secrets/hosts/MacBook-Pro-2.yaml
sops secrets/microvms/agent-sandbox-MacBook-Pro-2.yaml
```

In each SOPS editor, add a single-line YAML string alongside the existing keys:

```yaml
github-token: "YOUR_GITHUB_TOKEN"
```

Enter the actual values locally, not in chat. Keep the existing provider/MCP
entries. All four files need the new entry before deploying the shared
declaration.

## How gh gets the token

`hosts/darwin/shared.nix` declares the secret and a `gh-hosts.yml` SOPS template.
The template contains a placeholder during the build; SOPS substitutes the token
at activation. The resulting file has mode `0400` and belongs to the Mac user or
guest root. JSON syntax in that file is valid YAML for `gh`.

The Home Manager gh module links that rendered file to `~/.config/gh/hosts.yml`.
It still generates the non-secret `config.yml`, including the schema version
expected by gh. Legacy account migration is skipped for this managed file.

This works with direct Nix-store invocations of `gh`, not just shell aliases or
wrappers. The guest OpenCode service explicitly points `GH_CONFIG_DIR` at root's
gh configuration directory. The token itself is not exported into the service
environment.

The file provides one active GitHub token without hardcoding the GitHub username.
The HTTPS helper uses `x-access-token` as its username when necessary. Use
`gh api user --jq .login` to verify the actual account; an account label in
`gh auth status` may be empty without the optional username metadata.

Use SOPS for token changes rather than `gh auth login`, `logout`, `refresh`, or
`switch`. Those commands manage imperative account state and can conflict with
the managed file. Routine credential-helper `store` and `erase` operations are
no-ops in the pinned gh version.

## Deploy and verify

On each Mac, rebuild its matching output, then restart its VM. For example:

```sh
sudo darwin-rebuild switch --flake path:.#damascus
microvm restart
```

From a repository on the Mac:

```sh
gh api user --jq .login
git remote -v
```

GitHub remotes should resolve to SSH. Inside the corresponding VM:

```sh
gh api user --jq .login
gh config get git_protocol --host github.com
git remote -v
git ls-remote origin HEAD
```

The protocol and effective GitHub remotes should be HTTPS. `git ls-remote` checks
read access without changing the repository. Choose a private repository within
that VM token's permitted resource owner and selected repository list.

`GH_TOKEN` or `GITHUB_TOKEN` in the environment take precedence over the managed
file. If either was set previously, remove that override for this test. Do not
print those variables, run `gh auth token`, or print the managed credentials file
to inspect authentication. `gh api user --jq .login` prints only the public login.

After HTTPS is verified, revoke the old VM-specific GitHub SSH keys on GitHub if
you want the scoped tokens to be the guests' only GitHub credentials. The
configuration deliberately leaves the persisted guest SSH files untouched
during migration. Do not revoke the Macs' keys; the Macs still use SSH.
