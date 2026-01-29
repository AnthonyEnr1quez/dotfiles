{ config, pkgs, ... }: {
  catppuccin = {
    flavor = "mocha";

    cache.enable = true;

    bat.enable = true;
    eza.enable = true;
    fzf.enable = true;
    fish.enable = true;
    ghostty.enable = true;
    k9s.enable = true;
    kitty.enable = true;
    opencode.enable = true;
    zed.enable = true;
    zsh-syntax-highlighting.enable = true;
  };
}
