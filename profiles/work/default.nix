{ config, lib, pkgs, ... }: {
  user.name = "anthony.enriquez";

  hm = {
    home.sessionVariables = {
      SOPS_AGE_KEY_FILE = "${config.user.home}/.config/sops/age/keys.txt";
    };

    sops = {
      age.keyFile = "${config.user.home}/.config/sops/age/keys.txt";
      defaultSopsFile = ../../secrets/personal.sops.yaml;
      secrets.gh-hosts = {
        key = "gh_hosts";
        path = "${config.user.home}/.config/gh/hosts.yml";
      };
    };
  };
}
