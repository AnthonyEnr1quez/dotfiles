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

    vscode = {
      enable = true;
      package = pkgs.vscodium;
    };
    programs.vscode.profiles.default.userSettings."editor.fontFamily" = "Hack Nerd Font Mono";

    programs.zsh.profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';
  };
}
