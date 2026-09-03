{ config, inputs, lib, pkgs, ... }:
let
  cfg = config.agentSandbox;
  sbx = inputs.agent-sandbox.lib.${pkgs.stdenv.hostPlatform.system};
  go = config.home-manager.users.${config.user.name}.programs.go.package;

  opencode-sandboxed = sbx.mkSandbox {
    pkg = pkgs.opencode;
    binName = "opencode";
    outName = "opencode-sandboxed";
    allowedPackages = sbx.commonTools ++ [
      go
      pkgs.gopls
      pkgs.gnumake
      pkgs.gcc
      pkgs.gotest
      pkgs.gotestsum
      pkgs.nodejs
      pkgs.python3
      pkgs.gh
    ];

    # The launch directory is writable implicitly. All other projects are
    # readable through this grant, but remain outside the write boundary.
    roDirs = [ cfg.projectsDirectory "${config.user.home}/.config/opencode" ];
    roFiles = [
      "${config.user.home}/.config/git/config"
    ];
    rwDirs = [ "${config.user.home}/.local/share/opencode" ];

    # TODO: Add a sandbox-owned persistent Go cache if cold builds become a
    # measurable problem, without exposing the host's Go cache to the agent.
  };
in
{
  options.agentSandbox.projectsDirectory = lib.mkOption {
    type = lib.types.str;
    default = "${config.user.home}/projects";
    description = "Host projects directory exposed read-only to sandboxed agents";
  };

  config = {
    environment.systemPackages = [ opencode-sandboxed ];
    hm = {
      opencode.sandboxed = true;
      programs = {
        fish.shellAliases = {
          opencode = "opencode-sandboxed";
          opencode-local = lib.getExe pkgs.opencode;
        };
        zsh.shellAliases = {
          opencode = "opencode-sandboxed";
          opencode-local = lib.getExe pkgs.opencode;
        };
      };
    };
  };
}
