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

  config = mkIf cfg.enable {
    programs = {
      opencode = {
        enable = true;
      };

      ripgrep.enable = true; # dependency
    };
  };
}
