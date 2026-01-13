{ config, pkgs, ... }: {
  programs = {
    git = {
      enable = true;

      ignores = [
        ".DS_STORE"
      ];

      signing = {
        key = "~/.ssh/id_ed25519_github.pub";
      };

      # https://blog.gitbutler.com/how-git-core-devs-configure-git
      settings = {
        alias = {
          default-branch = "!git symbolic-ref refs/remotes/origin/HEAD | cut -d '/' -f3,4";
          com = "!f(){ git checkout $(git default-branch) $@;}; f";
          last = "log -1 HEAD";
          aa = "!git add . && git commit --amend --no-edit";
          amend = "commit --amend";
          poke = "!(git diff --exit-code --quiet && git diff --cached --exit-code --quiet) && git commit --allow-empty -m 'poke' || echo stash or revert any changes for ur poke";
        };
        branch.sort = "-committerdate";
        column.ui = "auto";
        commit = {
          gpgSign = true;
          verbose = true;
        };
        core = {
          editor = "vim --nofork";
        };
        diff = {
          algorithm = "histogram";
          colorMoved = "plain";
          mnemonicPrefix = true;
          renames = true;
        };
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile = toString (pkgs.writeText "allowed_signers" "");
        };
        help.autocorrect = "prompt";
        init.defaultBranch = "main";
        merge.conflictstyle = "zdiff3";
        pull.ff = "only";
        push.autoSetupRemote = true;
        rerere = {
          autoupdate = true;
          enabled = true;
        };
        tag.sort = "version:refname";
        url = {
          "git@github.com:" = {
            insteadOf = "https://github.com/";
          };
        };
      };
    };

    mergiraf.enable = true;
    difftastic = {
      enable = true;
      git.enable = true;
    };
  };
}
