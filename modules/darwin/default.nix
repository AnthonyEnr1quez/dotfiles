{ config, pkgs, ... }: {
  imports = [
    ../common.nix
    ./brew.nix
    ./preferences.nix
  ];

  system.primaryUser = "${config.user.name}";

  system.stateVersion = 5;

  # Make sure the nix daemon always runs
  # services.nix-daemon.enable = true;

  # nix.configureBuildUsers = true;
  ids.gids.nixbld = 30000;

  user.uid = 501;
  users.knownUsers = [
    "${config.user.name}"
  ];

  # NOTE: Keep these in sync with flake.nix nixConfig
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://anthonyenr1quez.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "anthonyenr1quez.cachix.org-1:Gclb+0ZEVse0quS5IhHiYRsb9QgZ7oSPRfKPNHOl3eI="
    ];
  };

  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 0; Minute = 0; };
    options = "--delete-older-than 30d";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];
}
