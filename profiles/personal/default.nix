{ config, lib, pkgs, ... }: {
  user.name = "ant";

  hm = {
    home.sessionVariables = {
      SOPS_AGE_KEY_FILE = "${config.user.home}/.config/sops/age/keys.txt";
    };
  };
}
