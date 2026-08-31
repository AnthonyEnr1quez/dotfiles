{ config, pkgs, lib, ... }: {
  hm = {
    firefox = {
      enable = lib.mkForce false;
    };
    zed = {
      enable = lib.mkForce false;
    };

    home.packages = with pkgs; [
      discord
    ];
  };

  # manual
  # http://jocala.com/adblink.html
  # black magic speed test

  homebrew = {
    brews = [
      # "ext4fuse" # needed w/ macfuse
    ];

    casks = [
      "balenaetcher"
      "bitwarden"
      # "blobsaver"
      "docker"
      "flux"
      "firefox@developer-edition"
      "geekbench"
      # "impactor"
      # "insomnia"
      # "keepingyouawake"
      "linearmouse"
      # "macfuse"
      "mullvad-vpn"
      # "obsidian"
      # "raycast"
      # "sensiblesidebuttons"
      "signal"
      "steam"
      # "unetbootin"
      # "vlc"
    ];
  };
}
