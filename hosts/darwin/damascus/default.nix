{ config, pkgs, lib, ... }: {
  # Set to true temporarily to (re)build the agent-sandbox micro VM locally,
  # then back to false to free the builder VM's resources. Normally the VM
  # closure is built in CI and pulled from cachix, so this can stay false.
  microvm.linuxBuilder.enable = false;

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
    home.stateVersion = "26.05";

    programs.firefox = {
      enable = true;
      package = pkgs.firefox-bin;
      profiles.jj.isDefault = true;
    };
  };

  homebrew = {
    casks = [
      "balenaetcher"
      "bitwarden"
      "mullvad-vpn"
      "signal"
    ];
  };
}
