{ config, inputs, lib, pkgs, ... }:
let
  cfg = config.agentSandbox;
  sbx = inputs.agent-sandbox.lib.${pkgs.stdenv.hostPlatform.system};
  go = config.home-manager.users.${config.user.name}.programs.go.package;
  git = config.home-manager.users.${config.user.name}.programs.git.settings;

  opencode-sandboxed = sbx.mkSandbox {
    pkg = pkgs.opencode;
    binName = "opencode";
    outName = "opencode-sandboxed";
    allowedPackages = sbx.commonTools ++ [
      go
      pkgs.gopls
      pkgs.gnumake
      pkgs.gnutar
      pkgs.gzip
      pkgs.gcc
      pkgs.clang
      pkgs.llvm
      pkgs.gotest
      pkgs.gotestsum
      # pkgs.nodejs
      pkgs.python3
      pkgs.gh
      pkgs.docker
      pkgs.wget
    ];

    # The launch directory is writable implicitly. All other projects are
    # readable through this grant, but remain outside the write boundary.
    roDirs = [ cfg.projectsDirectory "${config.user.home}/.config/opencode" ];
    # OrbStack's Docker daemon socket. Docker daemon access is host-privileged.
    roFiles = [ "${config.user.home}/.orbstack/run/docker.sock" ];
    rwDirs = [
      "${config.user.home}/.local/share/opencode"
      "${config.user.home}/.local/state/agent-sandbox/go-tmp"
    ];
    # Tests use httptest servers on unpredictable localhost ports, in addition
    # to the Docker-published endpoints.
    allowedLocalPorts = null;
    allowUnixSockets = true;

    # Do not expose the host Git config: it rewrites GitHub HTTPS URLs to SSH,
    # but the sandbox deliberately cannot access SSH keys. Git gets its identity
    # and an HTTPS credential helper from the environment instead.
    env = {
      GITHUB_TOKEN = "$GITHUB_TOKEN";
      GIT_AUTHOR_NAME = git.user.name;
      GIT_AUTHOR_EMAIL = git.user.email;
      GIT_COMMITTER_NAME = git.user.name;
      GIT_COMMITTER_EMAIL = git.user.email;
      GIT_CONFIG_GLOBAL = "/dev/null";
      GIT_CONFIG_COUNT = "1";
      GIT_CONFIG_KEY_0 = "credential.helper";
      GIT_CONFIG_VALUE_0 = "!${lib.getExe pkgs.gh} auth git-credential";
      DOCKER_HOST = "unix://${config.user.home}/.orbstack/run/docker.sock";
      # Go's Darwin cgo linker requires Nix's compatibility libresolv.
      CGO_LDFLAGS = "-L${pkgs.darwin.libresolv}/lib";
      # The sandbox temp directory is writable but not executable. Go runs
      # generated test binaries from GOTMPDIR, so use dedicated sandbox state.
      GOTMPDIR = "${config.user.home}/.local/state/agent-sandbox/go-tmp";
    };

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
      home.file.".local/state/agent-sandbox/go-tmp/.keep".text = "";
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
