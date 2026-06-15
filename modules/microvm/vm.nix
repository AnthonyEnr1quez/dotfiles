# NixOS configuration for the LLM/agent sandbox micro VM.
#
# Built for aarch64-linux and run on Apple Silicon macOS hosts via vfkit
# (Apple Virtualization framework). See:
# https://abhinavsarkar.net/notes/2026-microvm-nix/
#
# Networking note: vfkit only supports user-mode (NAT) networking. The VM can
# reach the host/internet outbound, but the host cannot initiate connections
# into the VM.
{ inputs, lib, pkgs, ... }:
{
  imports = [ ../common.nix ];

  networking.hostName = "agent-sandbox";
  services.getty.autologinUser = "root";

  microvm = {
    hypervisor = "vfkit";
    vcpu = 4;
    mem = 8192; # 8 GiB

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
      # NOTE: additional host directory shares (e.g. a projects/sandbox dir)
      # can be added here later, e.g.:
      # {
      #   proto = "virtiofs";
      #   tag = "projects";
      #   source = "/Users/<you>/projects";
      #   mountPoint = "/projects";
      # }
    ];

    interfaces = [
      {
        type = "user";
        id = "usernet";
        mac = "02:00:00:01:01:01";
      }
    ];
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

  # The opencode home-manager module references pkgs.opencode-session-search
  # (an overlay our host configs add). Provide it here too so the module works.
  nixpkgs.overlays = [
    (final: prev: {
      opencode-session-search =
        inputs.opencode-session-search.packages.${prev.stdenv.hostPlatform.system}.default;
    })
  ];

  # GUI/desktop home-manager modules are opt-in (default off); enable just the
  # opencode agent so an agent can run fully inside the sandbox.
  hm.opencode.enable = true;

  # Exit the sandbox by running `poweroff` at the prompt. (The microvm-run
  # Ctrl-] trick relies on tty signal chars, which don't fire under fish's line
  # editor, so `poweroff` is the reliable way out.)

  system.stateVersion = "26.05";
}
