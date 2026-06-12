{ config, pkgs, lib, ... }: {
  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };

    extraConfig = ''
      Host github.com
        AddKeysToAgent yes
        IdentityFile ~/.ssh/id_ed25519_github
    '';
  };
}
