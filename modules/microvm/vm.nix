# NixOS configuration for the LLM/agent sandbox micro VM.
#
# Built for aarch64-linux and run on Apple Silicon macOS hosts via vfkit
# (Apple Virtualization framework). See:
# https://abhinavsarkar.net/notes/2026-microvm-nix/
#
# Networking note: vfkit only supports user-mode (NAT) networking. The VM can
# reach the host/internet outbound, but the host cannot initiate connections
# into the VM.
{ lib, pkgs, config, ... }:
{
  imports = [ ../common.nix ];

  networking.hostName = "agent-sandbox";
  services.getty.autologinUser = "root";

  microvm = {
    hypervisor = "vfkit";
    vcpu = 4;
    mem = 8192; # 8 GiB

    # Disable the vfkit control socket. With a socket, microvm.nix wraps the
    # vfkit invocation in `bash -c '...'`, which causes the runtime-injected
    # `extraArgsScript` args (our projects/worktrees shares) to be passed to the
    # wrapper shell instead of vfkit — so the shares silently never attach.
    # We exit the VM with `poweroff` rather than the socket-based shutdown, so
    # dropping the socket costs us nothing.
    socket = null;

    # Writable overlay backed by a disk image so VM-local Nix builds/downloads
    # don't fill the tmpfs root (RAM).
    writableStoreOverlay = "/nix/.rw-store";

    volumes = [
      {
        image = "nix-store-overlay.img";
        mountPoint = "/nix/.rw-store";
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
      # NOTE: the projects (ro) and worktrees (rw) shares are NOT declared here.
      # Their host paths are per-user ($HOME differs across Macs), so baking a
      # source into the closure would hardcode a username. Instead they're
      # injected at launch via extraArgsScript below (which resolves $HOME at
      # runtime), and mounted guest-side via fileSystems by their mount tags.
    ];

    # Runtime-resolved virtiofs shares. This script runs on the host at launch
    # (as the invoking user), so $HOME is the real per-user home. Its stdout is
    # appended to the vfkit command line.
    #   - projects (ro):   host ~/projects            -> guest /root/projects
    #   - worktrees (rw):  host ~/.local/share/microvm/worktrees -> /root/worktrees
    # Built with vmHostPackages because this script runs on the macOS HOST at
    # launch (not in the guest), so it needs a host-executable (aarch64-darwin)
    # shell.
    extraArgsScript = "${config.microvm.vmHostPackages.writeShellScript "microvm-runtime-shares" ''
      echo \
        "--device" "virtio-fs,sharedDir=$HOME/projects,mountTag=projects" \
        "--device" "virtio-fs,sharedDir=$HOME/.local/share/microvm/worktrees,mountTag=worktrees"
    ''}";

    interfaces = [
      {
        type = "user";
        id = "usernet";
        mac = "02:00:00:01:01:01";
      }
    ];
  };

  # Guest mounts for the runtime-injected virtiofs shares (by mount tag).
  # projects is read-only; worktrees is read-write.
  #
  # `nofail` is important: these shares are injected at launch via
  # extraArgsScript, not baked into the closure. If they're ever missing (e.g.
  # the CI-built closure run without the wrapper), the VM must still boot rather
  # than drop to emergency mode. Also mark them not-needed-for-boot so they
  # don't block local-fs.target.
  fileSystems."/root/projects" = {
    device = "projects";
    fsType = "virtiofs";
    options = [ "ro" "nofail" "x-systemd.after=systemd-modules-load.service" ];
    neededForBoot = false;
  };
  fileSystems."/root/worktrees" = {
    device = "worktrees";
    fsType = "virtiofs";
    options = [ "nofail" "x-systemd.after=systemd-modules-load.service" ];
    neededForBoot = false;
  };

  networking.interfaces.eth0.useDHCP = true;

  systemd.tmpfiles.rules = [
    "d /nix/.rw-store/nix-build 0755 root root -"
  ];

  # Big gotcha workaround: the VM's root FS is a tmpfs (RAM), and Nix's build
  # sandbox is created on the root FS by default. Disable the sandbox and point
  # the build dir at the disk-backed overlay so builds don't exhaust RAM.
  nix.settings = {
    sandbox = false;
    build-dir = "/nix/.rw-store/nix-build";
    experimental-features = [ "nix-command" "flakes" ];
  };

  # System-level build toolchain (used by Go/cgo and general dev work).
  environment.systemPackages = with pkgs; [
    gnumake
    gcc

    # new-worktree <repo> [session] [base-branch]
    #   Creates an isolated, self-contained clone of a read-only host repo
    #   (~/projects/<repo>) under ~/worktrees/<repo>/<session>, checked out on a
    #   fresh `agent/<session>` branch based on <base-branch>. The agent works
    #   there; `microvm-fetch` on the host pulls the results back.
    (writeShellApplication {
      name = "new-worktree";
      runtimeInputs = [ git coreutils ];
      text = ''
        repo="''${1:-}"
        session="''${2:-$(date +%Y%m%d-%H%M%S)}"
        base="''${3:-}"

        if [ -z "$repo" ]; then
          echo "usage: new-worktree <repo> [session] [base-branch]" >&2
          echo "  <repo>        path under ~/projects (e.g. nix/dotfiles)" >&2
          exit 2
        fi

        src="$HOME/projects/$repo"
        dest="$HOME/worktrees/$repo/$session"

        if [ ! -d "$src/.git" ] && [ ! -f "$src/.git" ]; then
          echo "error: '$src' is not a git repo (is ~/projects/$repo shared?)" >&2
          exit 1
        fi
        if [ -e "$dest" ]; then
          echo "error: session already exists: $dest" >&2
          echo "       pick a different session name or remove it first." >&2
          exit 1
        fi

        mkdir -p "$(dirname "$dest")"
        # Self-contained clone (no shared objects) so it survives the source
        # repo being modified/gc'd on the host.
        git clone --no-hardlinks "$src" "$dest"

        cd "$dest"
        if [ -n "$base" ]; then
          git checkout "$base"
        fi
        git switch -c "agent/$session"

        echo "worktree ready: $dest (branch agent/$session)" >&2
        echo "$dest"
      '';
    })
  ];

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
  hm.opencode.enable = true;

  # Git identity for the sandbox. The `profiles/` module (which sets these on
  # real hosts) isn't imported by the VM, and the shared git module forces SSH
  # commit signing with a key that doesn't exist in the VM. Set an identity and
  # disable signing so the agent can commit; re-sign on the host when merging.
  hm.programs.git.settings = {
    user = {
      email = "32233059+AnthonyEnr1quez@users.noreply.github.com";
      name = "AnthonyEnr1quez";
    };
    commit.gpgSign = lib.mkForce false;
    tag.gpgSign = lib.mkForce false;
  };

  # Exit the sandbox by running `poweroff` at its shell prompt.

  system.stateVersion = "26.05";
}
