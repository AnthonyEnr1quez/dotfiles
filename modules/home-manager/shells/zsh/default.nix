{ config, pkgs, lib, ... }:
let
  ohmyzsh = pkgs.fetchFromGitHub {
    owner = "ohmyzsh";
    repo = "ohmyzsh";
    rev = "829b8fdea441208c08c9d231079f46215344cc46"; # master
    sha256 = "0d03bp51478f8wfxksj2k9jxhx886z4g5avly0iyd6j8il5fgkv1";
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
          rev = "13b34cdc29d8b22323fa2079193ea1529723747c"; # tags/v*
          sha256 = "0h9md5g4zfbwkifpdrf5skc1wrblq7mvggyczg1r17d20r87pvdy";
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
          rev = "f412a4bc807f733a18cdeca39eee906d82910302"; # master
          sha256 = "03wkf2jh7g4j1blcbcpf9x3dsj3s8m48v37p8dqd0vg5036qwbjp";
        };
        file = "kube-ps1.sh";
      }
    ];
  };
}
