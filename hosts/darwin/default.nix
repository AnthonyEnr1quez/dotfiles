{ host, config, pkgs, lib, ... }: {
  host.name = host;

  imports = [ ./${host} ];

  hm = {
    imports = [
      ../../modules/home-manager/catppuccin
    ];

    firefox-dev = {
      enable = true;
    };


    ghostty = {
      enable = true;
    };
    kitty = {
      enable = true;
    };

    programs = {
      vscode = {
        package = pkgs.vscodium;

        profiles.default.userSettings."editor.fontFamily" = "Hack Nerd Font Mono";
      };

      zsh.profileExtra = ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
    };
  };
}
