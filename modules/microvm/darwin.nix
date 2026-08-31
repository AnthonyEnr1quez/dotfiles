# Darwin-side wiring for a host's agent-sandbox micro VM.
#
# Provides:
#   * a `microvm-run` command on PATH that boots the VM via vfkit. Exit the VM
#     with `poweroff` from its shell.
#   * an opt-in NixOS linux-builder (aarch64-linux) needed to *build* the VM
#     closure. It is off by default; flip `microvm.linuxBuilder.enable = true`
#     and rebuild when you need to (re)build the VM, then turn it back off.
#
# Each enabled Darwin host selects its matching `agent-sandbox-<host>` output.
# The `microvm-run` wrapper builds the aarch64-linux VM closure LAZILY at runtime
# (via `nix build`) rather than embedding it as a build-time dependency of the
# darwin system. Embedding it would force every `darwin-rebuild` to build the
# VM, which requires the Linux builder and creates a chicken-and-egg problem.
{ config, host, lib, pkgs, self, ... }:
let
  cfg = config.microvm.linuxBuilder;

  flakeRef = self.outPath;
  runnerAttr = "nixosConfigurations.agent-sandbox-${host}.config.microvm.declaredRunner";

  opencode-vm = pkgs.writeShellScriptBin "opencode-vm" ''
    set -euo pipefail

    case "$PWD" in
      "$HOME/projects"|"$HOME/Projects")
        relative=""
        ;;
      "$HOME/projects/"*)
        relative="''${PWD#"$HOME/projects"}"
        ;;
      "$HOME/Projects/"*)
        relative="''${PWD#"$HOME/Projects"}"
        ;;
      *)
        echo "opencode-vm must be run under ~/projects" >&2
        exit 2
        ;;
    esac

    exec ${lib.getExe pkgs.opencode} attach http://192.168.64.2:4096 \
      --dir "/root/projects$relative" "$@"
  '';

  microvm-run = pkgs.writeShellScriptBin "microvm-run" ''
    set -euo pipefail

    echo "Building agent-sandbox micro VM for ${host} (this needs the Linux builder)..." >&2
    runner=$(${lib.getExe pkgs.nix} build --no-link --print-out-paths \
      "${flakeRef}#${runnerAttr}")

    # vfkit creates the VM's disk image(s) in the current directory (the image
    # paths in vm.nix are relative). Pin them to a stable per-user location so
    # `microvm-run` works from anywhere and reuses the same persistent store
    # overlay instead of littering images wherever it's launched.
    statedir="$HOME/.local/share/microvm"
    mkdir -p "$statedir"
    cd "$statedir"

    # vfkit's serial console is our stdio, but the host tty still generates
    # signals: Ctrl-C would SIGINT vfkit, whose signal handler gracefully
    # stops the whole VM. Undefine the signal chars so ^C/^\/^Z are sent to
    # the guest console (interrupting the process *inside* the VM) instead.
    # Exit the VM with `poweroff` at its prompt; if the guest ever hangs,
    # kill vfkit from another terminal.
    #
    # No `exec`: the EXIT trap must restore the tty after vfkit returns.
    saved_tty="$(stty -g)"
    trap 'stty "$saved_tty"' EXIT
    stty intr undef quit undef susp undef
    "$runner/bin/microvm-run"
  '';
in
{
  options.microvm.linuxBuilder.enable = lib.mkEnableOption ''
    the aarch64-linux NixOS linux-builder used to build the agent-sandbox
    micro VM. Enable temporarily while iterating on the VM config, then
    disable to free the builder VM's resources (see the sizing below)
  '';

  config = lib.mkMerge [
    { environment.systemPackages = [ microvm-run opencode-vm ]; }

    (lib.mkIf cfg.enable {
      nix = {
        distributedBuilds = true;
        linux-builder = {
          enable = true;
          systems = [ "aarch64-linux" ];

          # Beefed-up builder VM for faster aarch64-linux builds while iterating.
          # Defaults are ~1 vCPU / 3 GiB. Sized to leave headroom on a 16 GiB
          # M3 MacBook Air (8 cores): give the builder 6 cores / 6 GiB so macOS
          # keeps ~10 GiB and avoids heavy swapping.
          # (Only matters while linuxBuilder.enable = true.)
          maxJobs = 4;
          config = {
            virtualisation = {
              cores = 6;
              # nixpkgs currently selects GICv2 for aarch64 guests on Darwin,
              # but current macOS HVF only supports GICv3. Remove after updating
              # past https://github.com/NixOS/nixpkgs/pull/555928.
              qemu.options = [ "-machine virt,gic-version=3,accel=hvf:tcg" ];
              darwin-builder = {
                memorySize = 6144; # 6 GiB
                diskSize = 61440; # 60 GiB
              };
            };
          };
        };
      };
    })
  ];
}
