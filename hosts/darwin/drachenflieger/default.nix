{ config, pkgs, lib, ... }: {
  hm = {
    firefox-dev = {
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
      "mullvadvpn"
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
