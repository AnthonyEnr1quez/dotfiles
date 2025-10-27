{ config, pkgs, ... }: {
  programs = {
    git = {
      enable = true;

      difftastic.enable = true;

      extraConfig = {
        commit = {
          gpgSign = true;
        };
        core = {
          editor = "vim --nofork";
        };
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile = toString (pkgs.writeText "allowed_signers" "");
        };
        init.defaultBranch = "main";
        pull.ff = "only";
        push.autoSetupRemote = true;
        rerere = {
          autoupdate = true;
          enabled = true;
        };
        url = {
          "git@github.com:" = {
            insteadOf = "https://github.com/";
          };
        };
      };

      signing = {
        key = "~/.ssh/id_ed25519_github.pub";
      };

      ignores = [
        ".DS_STORE"
      ];

      aliases = {
        default-branch = "!git symbolic-ref refs/remotes/origin/HEAD | cut -d '/' -f3,4";
        com = "!f(){ git checkout $(git default-branch) $@;}; f";
        last = "log -1 HEAD";
        aa = "!git add . && git commit --amend --no-edit";
        amend = "commit --amend";
        poke = "!(git diff --exit-code --quiet && git diff --cached --exit-code --quiet) && git commit --allow-empty -m 'poke' || echo stash or revert any changes for ur poke";
      };
    };

    mergiraf.enable = true;
  };
}
