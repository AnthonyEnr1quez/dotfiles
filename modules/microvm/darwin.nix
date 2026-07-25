# Darwin-side wiring for the agent-sandbox micro VM.
#
# Provides:
#   * a `microvm-run` command on PATH that boots the VM via vfkit. Exit the VM
#     with `poweroff` from its shell.
#   * an opt-in NixOS linux-builder (aarch64-linux) needed to *build* the VM
#     closure. It is off by default; flip `microvm.linuxBuilder.enable = true`
#     and rebuild when you need to (re)build the VM, then turn it back off.
#
# The VM is defined in flake.nix as `nixosConfigurations.agent-sandbox`. The
# `microvm-run` wrapper builds the aarch64-linux VM closure LAZILY at runtime
# (via `nix build`) rather than embedding it as a build-time dependency of the
# darwin system. Embedding it would force every `darwin-rebuild` to build the
# VM, which requires the Linux builder and creates a chicken-and-egg problem.
{ config, lib, pkgs, self, ... }:
let
  cfg = config.microvm.linuxBuilder;

  flakeRef = self.outPath;
  runnerAttr = "nixosConfigurations.agent-sandbox.config.microvm.declaredRunner";

  microvm-run = pkgs.writeShellScriptBin "microvm-run" ''
    set -euo pipefail

    echo "Building agent-sandbox micro VM (this needs the Linux builder)..." >&2
    runner=$(${lib.getExe pkgs.nix} build --no-link --print-out-paths \
      "${flakeRef}#${runnerAttr}")

    # Restore terminal settings on exit (vfkit puts the tty in raw mode).
    cleanup() { stty "$(stty -g)"; }
    trap cleanup EXIT
    exec "$runner/bin/microvm-run"
  '';
in
{
  options.microvm.linuxBuilder.enable = lib.mkEnableOption ''
    the aarch64-linux NixOS linux-builder used to build the agent-sandbox
    micro VM. Enable temporarily while iterating on the VM config, then
    disable to free the builder VM's resources (see the sizing below)
  '';

  config = {
    environment.systemPackages = [ microvm-run ];

    nix = lib.mkIf cfg.enable {
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
            darwin-builder = {
              memorySize = 6144; # 6 GiB
              diskSize = 61440; # 60 GiB
            };
          };
        };
      };
    };
  };
}
