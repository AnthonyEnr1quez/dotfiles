{ lib, config, pkgs, ... }:
let
  name = "zed";
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
    programs.zed-editor = {
      enable = true;
    };
  };
}
