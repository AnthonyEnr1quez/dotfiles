{ config, lib, ... }:
let
  cfg = config.programs.gh;
in
{
  options.programs.gh.runtimeConfigDir = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Non-persistent GitHub CLI configuration directory.";
  };

  config = {
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = false;
      settings.telemetry = "disabled";
    };

    home.sessionVariables = lib.mkIf (cfg.runtimeConfigDir != null) {
      GH_CONFIG_DIR = cfg.runtimeConfigDir;
    };
  };
}
