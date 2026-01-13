{ lib, pkgs, config, modulesPath, ... }:
with lib;
{
  imports = [
    # "${modulesPath}/profiles/minimal.nix" disable to get man pages https://github.com/NixOS/nixpkgs/blob/410496d0f378b7510060cd8bff4f77bd101b4af8/nixos/modules/profiles/minimal.nix#L14
    ../common.nix
  ];

  time.timeZone = "America/Chicago";

  system.stateVersion = "25.11";
  environment.systemPackages = with pkgs; [ git vim wget bottom ];

  # users.users.nixos.isNormalUser = true;
  user.isNormalUser = true;

  networking.hostName = "${config.host.name}";

  # Enable nix flakes
  nix.package = pkgs.nixVersions.stable;
}
