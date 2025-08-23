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
    };

    shellAliases = {
      # https://github.com/ibraheemdev/modern-unix
      cat = "bat";
      ls = "eza -1"; #todo can delete??

      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
      "......" = "../../../../..";
    };

    shellInit = ''
      set -g fish_greeting # remove hello fish text
      set -g lucid_dirty_indicator "✗"
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
            sha256 = "sha256-6HepVxMm9LdJoifczvQS98kAc1+RTKJh+OHRf28nhZM=";
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
