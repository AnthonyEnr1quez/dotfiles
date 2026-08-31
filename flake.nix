{
  description = "dotfiles";

  # NOTE: Keep these in sync with modules/darwin/default.nix nix.settings
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://catppuccin.cachix.org"
      "https://anthonyenr1quez.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      "anthonyenr1quez.cachix.org-1:Gclb+0ZEVse0quS5IhHiYRsb9QgZ7oSPRfKPNHOl3eI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      inputs.flake-parts.follows = "flake-parts";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-vscode-extensions, flake-utils, home-manager, nur, darwin, microvm, nixos-wsl, vscode-server, ... }:
    let
      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system ? "aarch64-darwin"
        , host
        , nixpkgs ? inputs.nixpkgs
          , stable ? inputs.stable # # TODO is this needed with no overlays?
          , baseModules ? [
            home-manager.darwinModules.home-manager
            inputs.sops-nix.darwinModules.sops
            (
              { pkgs, config, inputs, ... }:
                {
                  nixpkgs.overlays = [
                    nur.overlays.default
                    nix-vscode-extensions.overlays.default
                  ];
                  home-manager.sharedModules = [
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
            inputs.sops-nix.nixosModules.sops
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

      mkMicrovmConfig =
        { host }:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit self inputs host; };
          modules = [
            microvm.nixosModules.microvm
            home-manager.nixosModules.home-manager
            ./modules/microvm/vm.nix
            { microvm.vmHostPackages = nixpkgs.legacyPackages.aarch64-darwin; }
          ];
        };

    in
    {
      darwinConfigurations = {
        damascus = mkDarwinConfig { host = "damascus"; };
        MacBook-Pro-2 = mkDarwinConfig { host = "MacBook-Pro-2"; profile = "work"; };
      };

      nixosConfigurations = {
        agent-sandbox-damascus = mkMicrovmConfig {
          host = "damascus";
        };

        agent-sandbox-MacBook-Pro-2 = mkMicrovmConfig {
          host = "MacBook-Pro-2";
        };

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
        formatter = pkgs.nixpkgs-fmt;
      }
    )
    //
    {
      # An aarch64-darwin vfkit runner (declaredRunner) pulls in one extra
      # aarch64-linux path — the guest's closureInfo (regInfo) — that is NOT in
      # `system.build.toplevel`. CI builds these on the arm-linux runner so they
      # land in cachix; otherwise the arm-macos job can't substitute them and
      # has no Linux builder to build the runners.
      packages.aarch64-linux = {
        agent-sandbox-damascus-runner-deps =
          let
            cfg = self.nixosConfigurations.agent-sandbox-damascus;
          in
          cfg.pkgs.closureInfo { rootPaths = [ cfg.config.system.build.toplevel ]; };

        agent-sandbox-MacBook-Pro-2-runner-deps =
          let
            cfg = self.nixosConfigurations.agent-sandbox-MacBook-Pro-2;
          in
          cfg.pkgs.closureInfo { rootPaths = [ cfg.config.system.build.toplevel ]; };
      };
    };
}
