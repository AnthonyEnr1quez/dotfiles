{ config, pkgs, lib, ... }: {
  hm = {
    firefox = {
      bookmarksToolbar = "never";
      extraExtensions = with pkgs.nur.repos.rycee.firefox-addons; [
        facebook-container
        multi-account-containers
        news-feed-eradicator
        reddit-enhancement-suite
      ];
    };

    home.packages = with pkgs; [
      discord
    ];
  };

  users.users.jen.home = "/Users/jen";
  home-manager.users.jen = {
    home.stateVersion = "25.11";

    programs.firefox = {
      enable = true;
      profiles.jj.isDefault = true;
    };
  };

  homebrew = {
    casks = [
      "balenaetcher"
      "bitwarden"
      "mullvad-vpn"
      "orbstack"
      "signal"
    ];
  };
}
