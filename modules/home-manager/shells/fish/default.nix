{ config, pkgs, lib, ... }: {
  imports = [
    ./abbr.nix
  ];

  programs.fish = {
    enable = true;

    generateCompletions = true;

    functions = {
      fish_right_prompt.body = ''
        set_color brblack
        echo -n "{"
        date "+%H:%M"
        echo -n "}"
        set_color normal
      '';

      fish_title = ''
        if test "$PWD" = "$HOME"
          set bpwd '~'
        else
          set bpwd (basename $PWD)
        end
        if set -q argv[1]
          echo $bpwd: $argv
        else
          echo $bpwd
        end
      '';
    };

    shellAliases = {
      # https://github.com/ibraheemdev/modern-unix
      cat = "bat";
      ls = "eza -1"; #todo can delete??
    };

    shellInit = ''
      set -g fish_greeting # remove hello fish text
      set -g lucid_dirty_indicator "✗"
      # Fix lucid.fish color variables - use just the color, not the theme flag
      set -g lucid_prompt_symbol_color $fish_color_normal[1]
      set -g lucid_prompt_symbol_error_color $fish_color_error[1]
    '';

    interactiveShellInit = ''
      # expand ... as ../..
      function expand-dot-to-parent-directory-path -d 'expand ... to ../.. etc'
          # get commandline up to cursor
          set -l cmd (commandline --cut-at-cursor)

          # match last line
          switch $cmd[-1]
              case '*..'
                  commandline --insert '/..'
              case '*'
                  commandline --insert '.'
          end
      end

      bind . 'expand-dot-to-parent-directory-path'
    '';

    plugins =
      map
        (p: {
          name = p.pname;
          inherit (p) src;
        })
        (with pkgs.fishPlugins; [
          # async-prompt
          autopair
          done
        ])
      ++
      [
        {
          name = "sponge";
          src = pkgs.fetchFromGitHub {
            owner = "halostatue";
            repo = "sponge";
            rev = "b09da3fcc543fd6e59e3d3ca791b150a1d080931"; # master
            sha256 = "sha256-oJgL2/okId8zSImGiBUux4nzAUEyfmxUy4Q0gAP94XY=";
          };
        }
        {
          name = "lucid.fish";
          src = pkgs.fetchFromGitHub {
            owner = "mattgreen";
            repo = "lucid.fish";
            rev = "b6aca138ce47289f2083bcb63c062d47dcaf4368"; # master
            sha256 = "14w54xppzlg1z1hs4k4ibxrh1jgp2bscxp17l94vgx162dbsjxz8";
          };
        }
        # {
        #   name = "kube-ps1";
        #   src = pkgs.fetchFromGitHub {
        #     owner = "jonmosco";
        #     repo = "kube-ps1";
        #     rev = "f412a4bc807f733a18cdeca39eee906d82910302"; # master
        #     sha256 = "03wkf2jh7g4j1blcbcpf9x3dsj3s8m48v37p8dqd0vg5036qwbjp";
        #   };
        #   file = "kube-ps1.fish";
        # }
      ];
  };
}
