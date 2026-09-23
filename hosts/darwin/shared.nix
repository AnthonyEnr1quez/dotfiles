{ config, ... }:
{
  # Shared by the Macs and their guests, each with its own ciphertext and user.
  sops.secrets = {
    openai-api-key.owner = config.user.name;
    anthropic-api-key.owner = config.user.name;
    github-token.owner = config.user.name;
  };

  # JSON is valid YAML. Only the placeholder enters the store; sops-nix renders
  # the token at activation, and gh reads it without a wrapper or token env var.
  sops.templates."gh-hosts.yml" = {
    owner = config.user.name;
    content = builtins.toJSON {
      "github.com" = {
        oauth_token = config.sops.placeholder.github-token;
        git_protocol = config.home-manager.users.${config.user.name}.programs.gh.settings.git_protocol;
      };
    };
  };
}
