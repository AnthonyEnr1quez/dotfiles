{ config, pkgs, lib, ... }:
let
  ohmyzsh = pkgs.fetchFromGitHub {
    owner = "ohmyzsh";
    repo = "ohmyzsh";
    rev = "f97e871c33da57d20e1b0411da6b1674126192a9"; # master
    sha256 = "14wcch5swvq2xqs3zs5hszrbi0rp8zvlj4wcz0rz45b61s9kss1g";
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
    dotDir = ".config/zsh";
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

    initExtra = builtins.readFile ./zshrc_extra;

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

    plugins = [
      {
        name = "fast-syntax-highlighting";
        file = "fast-syntax-highlighting.plugin.zsh";
        src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
      }
      {
        name = "zsh-abbr";
        src = pkgs.fetchFromGitHub {
          owner = "olets";
          repo = "zsh-abbr";
          rev = "f9e43d78110db0a8bf8ec75ca5b101a06b1d5ce8"; # tags/v*
          sha256 = "0pvj1mrbj66dg6nzwxcjw0821igmaakz112jcs6vlsqp1js05p49";
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
          rev = "b2286b63edf513ec0bfc425b55ceaffcf7e37b48"; # master
          sha256 = "0x0c0si0p45mmnjq6xkppdjpg9m32vp0cdx4d9bl5xdr67mmd9rr";
        };
        file = "kube-ps1.sh";
      }
    ];
  };
}
