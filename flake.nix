{
  description = "dotfiles";

  # NOTE: Keep these in sync with modules/darwin/default.nix nix.settings
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://catppuccin.cachix.org"
      "https://cache.numtide.com"
      "https://anthonyenr1quez.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "anthonyenr1quez.cachix.org-1:Gclb+0ZEVse0quS5IhHiYRsb9QgZ7oSPRfKPNHOl3eI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    systems.url = "github:nix-systems/default";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
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
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        blueprint.inputs.systems.follows = "systems";
        bun2nix.inputs = {
          flake-parts.follows = "flake-parts";
          systems.follows = "systems";
          treefmt-nix.follows = "llm-agents/treefmt-nix";
        };
      };
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-vscode-extensions, flake-utils, home-manager, nur, darwin, catppuccin, llm-agents, nixos-wsl, vscode-server, ... }:
    let
      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system ? "x86_64-darwin"
        , host
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable # # TODO is this needed with no overlays?
        , baseModules ? [
            home-manager.darwinModules.home-manager
            (
              { pkgs, config, inputs, ... }:
                {
                  nixpkgs.overlays = [
                    llm-agents.overlays.default
                    nur.overlays.default
                    nix-vscode-extensions.overlays.default
                  ];
                  home-manager.sharedModules = [
                    catppuccin.homeModules.catppuccin
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
                    llm-agents.overlays.default
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
