{ lib, config, pkgs, ... }:
let
  name = "opencode";
in
let
  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption;
in
{
  options.${name} = {
    enable = mkEnableOption name;
  };

  # models-dev marked as bad platform on intel darwin
  config = mkIf (cfg.enable && !(pkgs.stdenvNoCC.hostPlatform.isDarwin && pkgs.stdenvNoCC.hostPlatform.isx86_64)) {
    programs = {
      opencode = {
        enable = true;
      };

      ripgrep.enable = true; # dependency
    };
  };
}
