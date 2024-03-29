{ host, config, pkgs, lib, ... }: {
  host.name = host;

  imports = [ ./${host} ];

  hm = {
    imports = [ ./apps.nix ../../modules/home-manager/kitty ];

    disabledModules = [ "targets/darwin/linkapps.nix" ];

    programs.vscode = {
      package = pkgs.vscodium;

      userSettings."editor.fontFamily" = "Hack Nerd Font Mono";
    };
  };
}
