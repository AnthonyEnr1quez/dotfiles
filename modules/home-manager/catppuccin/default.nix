{ lib, config, pkgs, ... }:
let
  cfg = config.theming.catppuccin;

  inherit (lib) mkIf mkEnableOption mkOption types;
in
{
  options.theming.catppuccin = {
    enable = mkEnableOption "Catppuccin theming" // { default = true; };

    flavor = mkOption {
      type = types.str;
      default = "mocha";
      description = "Global Catppuccin flavor.";
    };
  };

  # Master toggle for the upstream catppuccin/nix home module. Because
  # autoEnable is off and this home-manager release is < 27.05, catppuccin.enable
  # acts as the global on/off switch: when false the whole module (including every
  # per-program catppuccin.<prog>.enable set alongside its program) is disabled.
  config = mkIf cfg.enable {
    catppuccin = {
      enable = true;
      autoEnable = false;
      flavor = cfg.flavor;
    };
  };
}
