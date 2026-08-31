{ config, pkgs, lib, ... }:
let
  goland = pkgs.jetbrains.goland.overrideAttrs (_: rec {
    version = "2026.2.1.1";
    src = pkgs.fetchurl {
      url = "https://download.jetbrains.com/go/goland-${version}-aarch64.dmg";
      hash = "sha256-61sgox2XxJTyjcxDrpi365t3fJgI0cr9tMSO9PxFzkY=";
    };
  });
in
{
  imports = [ ../../../modules/microvm/darwin.nix ];

  # GUI apps do not inherit Home Manager's shell session variables.
  launchd.user.envVariables.PKG_CONFIG_PATH =
    config.home-manager.users.${config.user.name}.home.sessionVariables.PKG_CONFIG_PATH;

  hm.home.packages = [ goland ];

  homebrew = {
    casks = [
      "google-drive"
      "linear"
      "notion"
      "1password"
    ];
  };

  system.defaults.LaunchServices.LSQuarantine = lib.mkForce true;
}
