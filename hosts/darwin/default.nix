{ host, config, pkgs, lib, ... }: {
  host.name = host;

  imports = [ ./${host} ];

  hm = {
    imports = [
      ../../modules/home-manager/catppuccin
    ];

    firefox = {
      enable = true;
    };

    ghostty = {
      enable = true;
    };
    kitty = {
      enable = true;
    };

    opencode = {
      enable = true;
    };

    vscode = {
      enable = true;
    };
    zed = {
      enable = true;
    };

    home.packages = with pkgs; [
      (lib.lowPrio orbstack) # low prio for bundled kubectl
      stats
    ];
  };
}
