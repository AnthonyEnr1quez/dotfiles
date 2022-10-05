# { lib, pkgs, config, modulesPath, ... }:

# with lib;
# let
#   # nixos-wsl = import ./nixos-wsl;
# in
# {
#   imports = [
#     "${modulesPath}/profiles/minimal.nix"

#     nixos-wsl.nixosModules.wsl
#   ];

#   wsl = {
#     enable = true;
#     automountPath = "/mnt";
#     defaultUser = "nixos";
#     startMenuLaunchers = true;

#     # Enable native Docker support
#     # docker-native.enable = true;

#     # Enable integration with Docker Desktop (needs to be installed)
#     # docker-desktop.enable = true;

#   };

#   # Enable nix flakes
#   nix.package = pkgs.nixFlakes;
#   nix.extraOptions = ''
#     experimental-features = nix-command flakes
#   '';

#   system.stateVersion = "22.05";
#   environment.systemPackages = with pkgs; [ git vim wget ];
# }

{ lib, pkgs, config, modulesPath, ... }:

with lib;
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    ../common.nix
  ];

  time.timeZone = "America/Chicago";

  system.stateVersion = "22.05";
  environment.systemPackages = with pkgs; [ git vim wget bottom ];

  # users.users.nixos.isNormalUser = true;
  user.isNormalUser = true;

  networking.hostName = "mothership";

  # Enable nix flakes
  nix.package = pkgs.nixVersions.stable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
}