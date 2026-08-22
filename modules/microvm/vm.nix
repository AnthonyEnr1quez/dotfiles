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
    # `extraArgsScript` args (our projects share) to be passed to the
    # wrapper shell instead of vfkit — so the share silently never attaches.
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
      # NOTE: the projects (rw) share is NOT declared here. Its host path is
      # per-user ($HOME differs across Macs), so baking a source into the
      # closure would hardcode a username. Instead it's injected at launch via
      # extraArgsScript below (which resolves $HOME at runtime), and mounted
      # guest-side via fileSystems by its mount tag.
    ];

    # Runtime-resolved virtiofs share. This script runs on the host at launch
    # (as the invoking user), so $HOME is the real per-user home. Its stdout is
    # appended to the vfkit command line.
    #   - projects (rw): host ~/projects -> guest /root/projects
    # Built with vmHostPackages because this script runs on the macOS HOST at
    # launch (not in the guest), so it needs a host-executable (aarch64-darwin)
    # shell.
    extraArgsScript = "${config.microvm.vmHostPackages.writeShellScript "microvm-runtime-shares" ''
      echo \
        "--device" "virtio-fs,sharedDir=$HOME/projects,mountTag=projects"
    ''}";

    interfaces = [
      {
        type = "user";
        id = "usernet";
        mac = "02:00:00:01:01:01";
      }
    ];
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
  # disable signing so the agent can commit; re-sign on the host if signed
  # history is needed.
  #
  # TODO: name/email are duplicated from profiles/default.nix. Importing
  # ./profiles here conflicts (personal/default.nix sets user.name = "ant" vs
  # the VM's root). Extract the identity to a shared module both can import.
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
