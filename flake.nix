{
  description = "dotfiles";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://anthonyenr1quez.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "anthonyenr1quez.cachix.org-1:Gclb+0ZEVse0quS5IhHiYRsb9QgZ7oSPRfKPNHOl3eI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-vscode-extensions, flake-utils, home-manager, nur, darwin, mac-app-util, catppuccin, nixos-wsl, vscode-server, ... }:
    let
      isDarwin = system:
        (builtins.elem system inputs.nixpkgs.lib.platforms.darwin);

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system ? "x86_64-darwin"
        , host
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable # # TODO is this needed with no overlays?
        , baseModules ? [
            mac-app-util.darwinModules.default
            home-manager.darwinModules.home-manager
            (
              { pkgs, config, inputs, ... }:
                {
                  nixpkgs.overlays = [
                    nur.overlays.default
                    nix-vscode-extensions.overlays.default
                  ];
                  home-manager.sharedModules = [
                    catppuccin.homeModules.catppuccin
                    mac-app-util.homeManagerModules.default
                    nur.modules.homeManager.default
                  ];
                }
            )
            ./modules/darwin
            ./hosts/darwin
            ./profiles
          ]
        , profile ? "personal"
        , extraModules ? [ ]
        }:
        inputs.darwin.lib.darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit self inputs nixpkgs host profile; };
        };

      # generate a base nixos configuration with the
      # specified overlays, hardware modules, and any extraModules applied
      mkNixosConfig =
        { system ? "x86_64-linux"
        , host
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , baseModules ? [
            home-manager.nixosModules.home-manager
            (
              { pkgs, config, inputs, ... }:
                {
                  nixpkgs.overlays = [
                    nix-vscode-extensions.overlays.default
                  ];
                }
            )
            ./modules/nixos
            ./hosts/linux
            ./profiles
          ]
        , profile ? "personal"
        , extraModules ? [ ]
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit self inputs nixpkgs host profile; };
        };
    in
    {
      darwinConfigurations = {
        drachenflieger = mkDarwinConfig { host = "drachenflieger"; };
        damascus = mkDarwinConfig { host = "damascus"; system = "aarch64-darwin"; };
        MacBook-Pro-2 = mkDarwinConfig { host = "MacBook-Pro-2"; system = "aarch64-darwin"; profile = "work"; };
      };

      nixosConfigurations = {
        mothership = mkNixosConfig {
          host = "mothership";
          extraModules = [
            nixos-wsl.nixosModules.wsl
            vscode-server.nixosModule
            ./modules/wsl
          ];
        };
      };
    }
    # The `//` operator takes the union of its two operands. So we are combining multiple attribute sets into one final, big flake.
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells = import ./shells { inherit pkgs; };
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
