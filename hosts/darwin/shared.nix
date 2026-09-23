{ config, ... }:
{
  # Shared by the Macs and their guests, each with its own ciphertext and user.
  sops.secrets = {
    openai-api-key.owner = config.user.name;
    anthropic-api-key.owner = config.user.name;
  };
}
