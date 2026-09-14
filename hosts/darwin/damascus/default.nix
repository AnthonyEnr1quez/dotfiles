{ config, ... }:
{
  # This module is evaluated separately on the Mac and its guest. Each uses
  # its own encrypted YAML, machine identity, and primary user.
  sops.secrets.openai-api-key.owner = config.user.name;

  hm.programs.opencode.settings.provider.openai.options.apiKey =
    "{file:${config.sops.secrets.openai-api-key.path}}";
}
