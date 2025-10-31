{ profile, config, pkgs, ... }: {
  imports = [ ./${profile} ];

  hm = {
    programs = {
      git = {
        settings = {
          user = {
            email = "32233059+AnthonyEnr1quez@users.noreply.github.com";
            name = "AnthonyEnr1quez";
          };
        };
      };
    };

    home.sessionVariables = {
      KUBECONFIG = "${config.user.home}/.config/kube/config";
    };
  };
}
