{ host, config, pkgs, lib, ... }: {
  host.name = host;

  imports = [
    ./${host}
    ../../modules/microvm/darwin.nix
  ];

  # Off by default: the agent-sandbox VM closure is built in CI and pulled from
  # cachix. Flip to true temporarily to (re)build the VM locally, then back.
  microvm.linuxBuilder.enable = false;

  hm = {
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
    mcp.enable = true;

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
