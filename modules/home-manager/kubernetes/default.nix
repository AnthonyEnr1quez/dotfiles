{ config, pkgs, ... }: {
  imports = [ ./k9s ];

  home = {
    packages = [ pkgs.kubectl ];
    sessionVariables.KUBECONFIG = "${config.home.homeDirectory}/.config/kube/config";
  };
}
