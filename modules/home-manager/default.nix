{ pkgs, lib, ... }: {
  imports = [
    ./ai
    ./editors
    ./firefox
    ./git
    ./k9s
    ./langs
    ./shells
    ./ssh
    ./terms
  ];

  home = {
    stateVersion = "26.05";

    packages = with pkgs; [
      # ansible
      # coreutils
      # cachix
      # element-desktop
      # git-crypt
      # gnused TODO figure out how to install as gsed (homebrew?)
      # gopass
      # iterm2
      # jetbrains.goland
      # jetbrains.idea-community
      kubectl
      kubectx
      # kubelogin
      # kubernetes-helm-wrapped
      # mouser TODO, gesture support is somewhat mid as of 06/26, swapped on offline logi-options-+ https://hub.sync.logitech.com/options/post/logi-options-offline-manual-I2a7NSJyE6oH2oy
      # pgadmin4
      # slack
      unar
      zlib
    ];
  };

  programs = {
    home-manager.enable = true;

    bat.enable = true;
    eza.enable = true;
    vim.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;

      # Hides the rather large block of text that is usually printed when entering the environment.
      # https://direnv.net/man/direnv.toml.1.html#codehideenvdiffcode
      config.global.hide_env_diff = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };

    fd.enable = true;

    # TODO explore more
    # gnupg.enable = true;
    # jq.enable = true;
    # ## compare
    # htop.enable = true;
    # btm.enable = true;
  };

  targets.darwin = lib.mkIf pkgs.stdenvNoCC.hostPlatform.isDarwin {
    copyApps.enable = true;
    linkApps.enable = false;
  };
}
