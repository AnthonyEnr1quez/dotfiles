{ config, pkgs, ... }: {
  catppuccin = {
    flavor = "mocha";

    bat.enable = true;
    eza.enable = true;
    fzf.enable = true;
    fish.enable = true;
    ghostty.enable = true;
    k9s.enable = true;
    kitty.enable = true;
    opencode.enable = true;
    zed = {
      enable = true;
      icons.enable = true;
    };
    zsh-syntax-highlighting.enable = true;
  };
}
