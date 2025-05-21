{ lib, config, pkgs, ... }:
let
  name = "ghostty";
in
let
  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption;
in
{
  options.${name} = {
    enable = mkEnableOption name;
  };

  config = mkIf cfg.enable {
    programs = {
      ghostty = {
        enable = true;
        package = pkgs.nur.repos.gigamonster256.ghostty-darwin;
        enableZshIntegration = true;
        installBatSyntax = true;

        settings = {
          auto-update = "off";
          clipboard-trim-trailing-spaces = true;
          font-family = "Hack Nerd Font";
          window-title-font-family = "Hack Nerd Font";
          font-size = 18;

          macos-option-as-alt = true;
          quit-after-last-window-closed = true;
          scrollback-limit = 100000000;

          theme = "catppuccin-mocha";

          # custom tab titles
          shell-integration-features = "no-title";

          # does not work with full screen apps :(
          keybind = "global:alt+space=toggle_quick_terminal";
          quick-terminal-position = "right";
          quick-terminal-animation-duration = 0;
          quick-terminal-autohide = false;
        };
      };

      # custom tab titles
      zsh.initContent = ''
        DISABLE_AUTO_TITLE="true"
        function precmd () {
          echo -ne "\033]0;$(basename $PWD)\007"
        }
        precmd

        function preexec () {
          print -Pn "\e]0;$\a"
        }
      '';
    };
  };
}
