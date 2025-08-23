{ config, pkgs, ... }: {
  catppuccin = {
    flavor = "mocha";

    bat.enable = true;
    fzf.enable = true;
    fish.enable = true;
    k9s.enable = true;
    kitty.enable = true;
    zsh-syntax-highlighting.enable = true;
  };
}
