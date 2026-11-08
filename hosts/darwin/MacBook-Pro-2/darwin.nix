{ config, pkgs, lib, ... }:
let
  goland = pkgs.jetbrains.goland.overrideAttrs (_: rec {
    version = "2026.3";
    src = pkgs.fetchurl {
      url = "https://download.jetbrains.com/go/goland-${version}-aarch64.dmg";
      hash = "sha256-j4NyfH3Qy91Qv6DkPMgeRP4NTeHnb2NLGaNlzHyGeCc=";
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
