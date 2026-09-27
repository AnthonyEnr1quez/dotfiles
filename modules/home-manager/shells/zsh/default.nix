{ config, pkgs, lib, ... }:
let
  ohmyzsh = pkgs.fetchFromGitHub {
    owner = "ohmyzsh";
    repo = "ohmyzsh";
    rev = "74965c96098134b192f00084f966b4b02438a739"; # master
    sha256 = "1ml0pbb0lrr3q3xkqqz3x2w59pz0y7vh4sbxf8cm8ms0isjbsbk4";
    # todo, cant auto update with sparse checkout?
    # use pkg???
    # sparseCheckout = [
    #   "plugins/sudo"
    #   "lib"
    #   "themes"
    # ];
  };
in
{
  catppuccin.zsh-syntax-highlighting.enable = true;

  # see also https://github.com/Yumasi/nixos-home/blob/master/zsh.nix#L89
  home.file = {
    ".config/zsh/zsh_abbr".source = ./zsh_abbr;
  };

  programs.zsh = {
    enable = true;

    autocd = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    autosuggestion.enable = true;
    enableCompletion = true;

    history = {
      expireDuplicatesFirst = true;
      extended = true;
      path = "${config.home.homeDirectory}/.config/zsh/zsh_history";
      save = 100000;
      size = 100000;
      share = true;
    };
    historySubstringSearch = {
      enable = true;
    };

    initContent = builtins.readFile ./zshrc_extra;

    sessionVariables = {
      ABBR_USER_ABBREVIATIONS_FILE = "${config.home.homeDirectory}/.config/zsh/zsh_abbr";
    };

    shellAliases = {
      # https://github.com/ibraheemdev/modern-unix
      cat = "bat";
      ls = "eza -1";
    };

    shellGlobalAliases = {
      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
      "......" = "../../../../..";
    };

    syntaxHighlighting = {
      enable = true;
      highlighters = [ "main" "brackets" "pattern" "line" "cursor" "root" ];
    };

    plugins = [
      # this is slow af now for make and unusable :(
      # https://github.com/zdharma-continuum/fast-syntax-highlighting/pull/82
      # {
      #   name = "fast-syntax-highlighting";
      #   file = "fast-syntax-highlighting.plugin.zsh";
      #   src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
      # }
      {
        name = "zsh-abbr";
        src = pkgs.fetchFromGitHub {
          owner = "olets";
          repo = "zsh-abbr";
          rev = "644e230c51aaf8aac01267a0f5c0f92ba001b700"; # tags/v*
          sha256 = "0cri56f13yqb9hrzxf2xzrbblg9bmxc7pk3ckv61y23v2ssigycx";
          fetchSubmodules = true;
        };
        file = "zsh-abbr.plugin.zsh";
      }
      {
        name = "sudo";
        src = ohmyzsh;
        file = "plugins/sudo/sudo.plugin.zsh";
      }
      {
        name = "git";
        src = ohmyzsh;
        file = "lib/git.zsh";
      }
      {
        name = "async-prompt";
        src = ohmyzsh;
        file = "lib/async_prompt.zsh";
      }
      {
        name = "prompt_info_functions";
        src = ohmyzsh;
        file = "lib/prompt_info_functions.zsh";
      }
      {
        name = "theme-and-appearance";
        src = ohmyzsh;
        file = "lib/theme-and-appearance.zsh";
      }
      {
        name = "crunch";
        src = ohmyzsh;
        file = "themes/crunch.zsh-theme";
      }
      {
        name = "kube-ps1 ";
        src = pkgs.fetchFromGitHub {
          owner = "jonmosco";
          repo = "kube-ps1";
          rev = "7aaaeee5eaa29f920acd850ea63839d9f87b8ac5"; # master
          sha256 = "0lkjqvrkvwmva83sbdzzdkhzlg1hxj93py0d019ikx9pk4g1d374";
        };
        file = "kube-ps1.sh";
      }
    ];
  };
}
