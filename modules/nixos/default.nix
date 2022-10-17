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
    # "${modulesPath}/profiles/minimal.nix" disable to get man pages https://github.com/NixOS/nixpkgs/blob/410496d0f378b7510060cd8bff4f77bd101b4af8/nixos/modules/profiles/minimal.nix#L14
    ../common.nix
  ];

  time.timeZone = "America/Chicago";

  system.stateVersion = "22.05";
  environment.systemPackages = with pkgs; [ git vim wget bottom ];

  # users.users.nixos.isNormalUser = true;
  user.isNormalUser = true;

  networking.hostName = "${config.host.name}";

  # Enable nix flakes
  nix.package = pkgs.nixVersions.stable;
  # nix.extraOptions = ''
  #   experimental-features = nix-command flakes
  # '';
}
