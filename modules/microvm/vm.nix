# NixOS configuration for the LLM/agent sandbox micro VM.
#
# Built for aarch64-linux and run on Apple Silicon macOS hosts via vfkit
# (Apple Virtualization framework). See:
# https://abhinavsarkar.net/notes/2026-microvm-nix/
#
# Networking note: vfkit only supports user-mode (NAT) networking. It does not
# forward localhost ports, so the host discovers the guest's DHCP lease by its
# fixed MAC address rather than assuming a particular IP.
{ lib, pkgs, config, host, ... }:
let
  developmentEnvironment = {
    TMPDIR = "/var/lib/dev-state/tmp";
    XDG_CACHE_HOME = "/var/lib/dev-state/cache";
    GOPATH = "/var/lib/dev-state/go";
    GOMODCACHE = "/var/lib/dev-state/go/pkg/mod";
    GOCACHE = "/var/lib/dev-state/cache/go-build";
    GOTMPDIR = "/var/lib/dev-state/tmp/go";
  };
in
{
  imports = [ ../common.nix ]
    ++ lib.optional (host != null) (../../hosts/darwin + "/${host}");

  networking.hostName = "agent-sandbox";
  services.getty.autologinUser = "root";

  microvm = {
    hypervisor = "vfkit";
    vcpu = 4;
    mem = 8192; # 8 GiB
    # No swap by design. If large builds or containers are OOM-killed, add a
    # small disk-backed swap device rather than placing swap on the tmpfs root.
    vfkit.extraArgs = [ "--pidfile" "vfkit.pid" ];

    # Keep upstream's socket wrapper disabled: its `bash -c '...'` swallows
    # extraArgsScript arguments instead of forwarding them to vfkit. Inject
    # --restful-uri directly below; the host launcher owns socket shutdown.
    socket = null;

    # Writable overlay backed by a disk image so VM-local Nix builds/downloads
    # don't fill the tmpfs root (RAM).
    writableStoreOverlay = "/nix/.rw-store";
    # Upstream loads the booted closure's regInfo into the DB on EVERY boot,
    # before systemd/Nix clients start. Keep this even when the DB already
    # exists, so a newly downloaded VM closure is registered too.
    registerClosure = true;

    volumes = [
      {
        image = "nix-store-overlay.img";
        mountPoint = "/nix/.rw-store";
        size = 40960; # 40 GiB
      }
      # Persistent opencode state, symlinked out of the tmpfs /root via the
      # tmpfiles rules below. Sparse image: the size is a cap, not an
      # allocation.
      {
        image = "agent-state.img";
        mountPoint = "/var/lib/agent-state";
        size = 10240; # 10 GiB
      }
      # Persistent development state for compiler/test scratch space and tool
      # caches. Keeping it separate from agent state prevents either workload
      # from exhausting the other's storage budget.
      {
        image = "dev-state.img";
        mountPoint = "/var/lib/dev-state";
        size = 40960; # 40 GiB
      }
    ];

    shares = [
      # Host's read-only Nix store, combined with the writable overlay above.
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      # NOTE: the projects (rw) share is NOT declared here. Its host path is
      # per-user ($HOME differs across Macs), so baking a source into the
      # closure would hardcode a username. Instead it's injected at launch via
      # extraArgsScript below (using launcher-provided paths), and mounted
      # guest-side via fileSystems by its mount tag.
    ];

    # Runtime-resolved shares and control socket. Stdout is appended to vfkit's
    # command line with upstream shell word-splitting/globbing, so the launcher
    # must reject whitespace, commas and glob characters in these host paths.
    # The launcher must supply AGENT_PROJECTS_DIR; leaving it unset only
    # supports diagnostic boots without the projects share or OpenCode service.
    #   - projects (rw): host AGENT_PROJECTS_DIR -> guest /root/projects
    #   - agent-secrets: launch-scoped host secrets -> guest /run/host-secrets
    # Built with vmHostPackages because this script runs on the macOS HOST at
    # launch (not in the guest), so it needs a host-executable (aarch64-darwin)
    # shell.
    extraArgsScript = "${config.microvm.vmHostPackages.writeShellScript "microvm-runtime-shares" ''
      if [ -n "''${AGENT_PROJECTS_DIR:-}" ]; then
        echo \
          "--device" "virtio-fs,sharedDir=$AGENT_PROJECTS_DIR,mountTag=projects"
      fi
      if [ -n "''${AGENT_SECRETS_DIR:-}" ]; then
        echo \
          "--device" "virtio-fs,sharedDir=$AGENT_SECRETS_DIR,mountTag=agent-secrets"
      fi
      if [ -n "''${AGENT_CONTROL_SOCKET:-}" ]; then
        echo "--restful-uri" "unix://$AGENT_CONTROL_SOCKET"
      fi
    ''}";

    interfaces = [
      {
        type = "user";
        id = "usernet";
        mac = "02:00:00:01:01:01";
      }
    ];
  };

  # vfkit uses the scripted initrd in pinned microvm.nix. Bind the entire Nix
  # state before stage-2 activation and upstream's postBootCommands registration,
  # not a late tmpfiles symlink that would hide a freshly populated tmpfs DB.
  # postMountCommands runs after the overlay volume is mounted, allowing a new
  # backing directory to be created on first boot without moving/deleting data.
  boot.initrd.systemd.enable = false;
  boot.initrd.postMountCommands = ''
    mkdir -p /mnt-root/nix/.rw-store/nix-var /mnt-root/nix/var/nix || fail
    mount -o bind /mnt-root/nix/.rw-store/nix-var /mnt-root/nix/var/nix || fail
  '';
  fileSystems."/nix/var/nix" = {
    device = "/nix/.rw-store/nix-var";
    fsType = "none";
    options = [ "bind" ];
    # Mounted manually above: stage-1's normal mount loop would wait for the
    # nonexistent source directory on a fresh volume. Keep fstab for systemd.
    neededForBoot = false;
  };

  # Guest mount for the runtime-injected virtiofs share (by mount tag).
  # Read-write by design: agents work directly in the real repos. Git is the
  # undo layer; the VM is the execution jail. See README.md for the trust
  # model.
  #
  # `nofail` is important: this share is injected at launch via
  # extraArgsScript, not baked into the closure. If it's ever missing (e.g.
  # the CI-built closure run without the wrapper), the VM must still boot rather
  # than drop to emergency mode. Also mark it not-needed-for-boot so it
  # doesn't block local-fs.target.
  fileSystems."/root/projects" = {
    device = "projects";
    fsType = "virtiofs";
    options = [ "nofail" "x-systemd.after=systemd-modules-load.service" ];
    neededForBoot = false;
  };

  # The host attaches this mount only for a launch with agent credentials. It
  # stays optional for diagnostic boots; OpenCode itself requires both shares.
  fileSystems."/run/host-secrets" = {
    device = "agent-secrets";
    fsType = "virtiofs";
    options = [ "nofail" "x-systemd.after=systemd-modules-load.service" ];
    neededForBoot = false;
  };

  networking.useDHCP = true;
  networking.firewall.allowedTCPPorts = [ 4096 ];

  # Persist VM-specific credentials and agent state on the agent-state volume:
  # create the backing dirs and symlink them into root's tmpfs home. tmpfiles
  # runs after local-fs.target (volume mounted) and before home-manager
  # activation writes application state.
  #
  # Deliberately a static list: which paths persist is a property of this VM,
  # not of the apps' home-manager config.
  systemd.tmpfiles.rules =
    let
      persist = name: target: [
        "d /var/lib/agent-state/${name} 0700 root root -"
        "L+ ${target} - - - - /var/lib/agent-state/${name}"
      ];
    in
    [
      "d /nix/.rw-store/nix-build 0755 root root -"
      "d /var/lib/dev-state/tmp 0700 root root -"
      "d /var/lib/dev-state/tmp/go 0700 root root -"
      "d /var/lib/dev-state/cache 0700 root root -"
      "d /var/lib/dev-state/go 0700 root root -"
      "d /var/lib/dev-state/docker 0710 root root -"
      "d /root/.ssh 0700 root root -"
      "d /var/lib/agent-state/github-ssh 0700 root root -"
      "L+ /root/.ssh/id_ed25519_github - - - - /var/lib/agent-state/github-ssh/id_ed25519_github"
      "L+ /root/.ssh/id_ed25519_github.pub - - - - /var/lib/agent-state/github-ssh/id_ed25519_github.pub"
      "L+ /root/.ssh/known_hosts - - - - /var/lib/agent-state/github-ssh/known_hosts"
    ]
    # opencode: sessions/history/db; gcloud: configs and refresh credentials;
    # github-ssh: VM-specific identity key only
    ++ persist "opencode" "/root/.local/share/opencode"
    ++ persist "gcloud" "/root/.config/gcloud";

  # Keep development tools from filling the tmpfs root. These apply to login
  # shells; the OpenCode service receives the same values explicitly below.
  hm.home.sessionVariables = developmentEnvironment // {
    GOPATH = lib.mkForce developmentEnvironment.GOPATH;
  };

  # Big gotcha workaround: the VM's root FS is a tmpfs (RAM), and Nix's build
  # sandbox is created on the root FS by default. Disable the sandbox and point
  # the build dir at the disk-backed overlay so builds don't exhaust RAM.
  nix.settings = {
    sandbox = false;
    build-dir = "/nix/.rw-store/nix-build";
    experimental-features = [ "nix-command" "flakes" ];
    # NOTE: Keep these in sync with flake.nix nixConfig and nix.settings in
    # modules/darwin/default.nix.
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://catppuccin.cachix.org"
      "https://anthonyenr1quez.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      "anthonyenr1quez.cachix.org-1:Gclb+0ZEVse0quS5IhHiYRsb9QgZ7oSPRfKPNHOl3eI="
    ];
  };

  # System-level build toolchain (used by Go/cgo and general dev work).
  environment.systemPackages = with pkgs; [
    bc
    gnumake
    gcc
  ];

  # Rootful Docker for the agent (root is the VM's only user, so there's no
  # privilege-separation benefit to rootless). Images, containers, and volumes
  # use the disk-backed development state instead of exhausting root tmpfs.
  virtualisation.docker = {
    enable = true;
    daemon.settings.data-root = "/var/lib/dev-state/docker";
  };

  # Treat the VM like another machine: reuse the shared system config
  # (modules/common.nix), which bootstraps home-manager and pulls in the full
  # modules/home-manager tooling barrel. The primary user here is root (the
  # autologin user), so the tooling applies to root.
  user = {
    name = "root";
    # common.nix derives this as /home/<name>; root's home is /root.
    home = lib.mkForce "/root";
  };

  # GUI/desktop home-manager modules are opt-in (default off); enable just the
  # opencode agent so an agent can run fully inside the sandbox.
  #
  # sandboxed = true relaxes bash/skill/external-directory "ask" prompts that
  # only guard against unrestrained *host* execution, since that execution is
  # already jailed by the VM. Rules protecting live repo state (git, rm) and
  # secrets (read denies) are left untouched: ~/projects is a real, writable
  # mount of the host repos, so those risks aren't mitigated by the VM
  # boundary. See modules/home-manager/ai/opencode/default.nix.
  hm.opencode = {
    enable = true;
    sandboxed = true;
    server = true;
  };
  # The credential symlinks under /root are denied by the shared OpenCode
  # policy. Deny their VM-specific backing paths too, so direct paths cannot
  # bypass those file-tool guards.
  hm.programs.opencode.settings.permission = {
    read = {
      "/var/lib/agent-state/opencode/auth.json" = "deny";
      "/var/lib/agent-state/gcloud/**" = "deny";
      "/var/lib/agent-state/github-ssh/**" = "deny";
    };
    external_directory = {
      "/var/lib/agent-state/opencode/auth.json" = "deny";
      "/var/lib/agent-state/gcloud" = "deny";
      "/var/lib/agent-state/gcloud/*" = "deny";
      "/var/lib/agent-state/github-ssh" = "deny";
      "/var/lib/agent-state/github-ssh/*" = "deny";
    };
  };
  hm.herdr.enable = false;
  hm.mcp.enable = true;

  systemd.services.opencode = {
    description = "OpenCode server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [ "home-manager-root.service" ];
    after = [ "network-online.target" "home-manager-root.service" ];
    # nofail keeps missing runtime shares from preventing diagnostic VM boots,
    # but the server must never start against unmounted paths or an inactive HM.
    unitConfig.RequiresMountsFor = [ "/root/projects" "/run/host-secrets" ];

    environment = developmentEnvironment // {
      HOME = "/root";
      PATH = lib.mkForce "/etc/profiles/per-user/root/bin:/run/current-system/sw/bin";
      OPENCODE_DISABLE_PROJECT_CONFIG = "1";
    };

    serviceConfig = {
      EnvironmentFile = "/run/host-secrets/opencode.env";
      ExecStart = "${lib.getExe pkgs.opencode} serve";
      Restart = "on-failure";
      RestartSec = 2;
      WorkingDirectory = "/root";
    };
  };

  # The shared git module enables SSH commit signing with a key that does not
  # exist in the VM. Disable signing so the agent can commit; re-sign on the
  # host if signed history is needed.
  hm.programs.git.settings = {
    commit.gpgSign = lib.mkForce false;
    tag.gpgSign = lib.mkForce false;
  };

  # Exit the sandbox by running `poweroff` at its shell prompt.

  system.stateVersion = "26.05";
}
