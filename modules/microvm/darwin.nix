# Darwin-side wiring for the agent-sandbox micro VM.
#
# Provides:
#   * a `microvm-run` command on PATH that boots the VM via vfkit, rebinding
#     Ctrl-] to the interrupt/suspend/quit signals so Ctrl-C works *inside*
#     the VM without shutting it down.
#   * an opt-in NixOS linux-builder (aarch64-linux) needed to *build* the VM
#     closure. It is off by default; flip `microvm.linuxBuilder.enable = true`
#     and rebuild when you need to (re)build the VM, then turn it back off.
#
# The VM is defined in flake.nix as `nixosConfigurations.agent-sandbox`. The
# `microvm-run` wrapper builds the aarch64-linux VM closure LAZILY at runtime
# (via `nix build`) rather than embedding it as a build-time dependency of the
# darwin system. Embedding it would force every `darwin-rebuild` to build the
# VM, which requires the Linux builder and creates a chicken-and-egg problem.
{ config, lib, pkgs, self, inputs, ... }:
let
  cfg = config.microvm.linuxBuilder;

  # nixpkgs-unstable's qemu 11.0.0 crashes the linux-builder VM on macOS
  # (SIGABRT in hvf_arch_init_vcpu under Hypervisor.framework).
  # See https://github.com/NixOS/nixpkgs/issues/528299. Use the stable
  # (nixos-26.05) builder, which ships qemu 10.2.2 and works.
  stablePkgs = inputs.stable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  flakeRef = self.outPath;
  runnerAttr = "nixosConfigurations.agent-sandbox.config.microvm.declaredRunner";

  microvm-run = pkgs.writeShellScriptBin "microvm-run" ''
    set -euo pipefail

    echo "Building agent-sandbox micro VM (this needs the Linux builder)..." >&2
    runner=$(${lib.getExe pkgs.nix} build --no-link --print-out-paths \
      "${flakeRef}#${runnerAttr}")

    cleanup() { stty "$(stty -g)"; }
    trap cleanup EXIT
    stty intr ^] susp ^] quit ^]
    exec "$runner/bin/microvm-run"
  '';
in
{
  options.microvm.linuxBuilder.enable = lib.mkEnableOption ''
    the aarch64-linux NixOS linux-builder used to build the agent-sandbox
    micro VM. Enable temporarily while iterating on the VM config, then
    disable to free the builder VM's resources (~1 vCPU / 3 GiB RAM)
  '';

  config = {
    environment.systemPackages = [ microvm-run ];

    nix = lib.mkIf cfg.enable {
      distributedBuilds = true;
      linux-builder = {
        enable = true;
        package = stablePkgs.darwin.linux-builder;
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
