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
