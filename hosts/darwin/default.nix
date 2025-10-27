{ host, config, pkgs, lib, ... }: {
  host.name = host;

  imports = [ ./${host} ];

  hm = {
    imports = [
      ../../modules/home-manager/catppuccin
    ];

    firefox = {
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
    zed = {
      enable = true;
    };

    home.packages = with pkgs; [
      stats
    ];

    # todo same for fish?
    programs.zsh.profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';
  };
}
