{ config, ... }:
{
  # Shared by the Macs and their guests, each with its own ciphertext and user.
  sops.secrets = {
    openai-api-key.owner = config.user.name;
    anthropic-api-key.owner = config.user.name;
    github-token.owner = config.user.name;
  };

  # gh accepts JSON as YAML; sops-nix substitutes the token at activation.
  sops.templates."gh-hosts.yml" = {
    owner = config.user.name;
    content = builtins.toJSON {
      "github.com".oauth_token = config.sops.placeholder.github-token;
    };
  };
}
