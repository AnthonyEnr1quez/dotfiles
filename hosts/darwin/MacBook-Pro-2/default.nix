{ config, pkgs, lib, ... }:
let
  mfPath = "${config.user.home}/Projects/moov/mf";

  goland = pkgs.jetbrains.goland.overrideAttrs (_: rec {
    version = "2026.1.1";
    src = pkgs.fetchurl {
      url = "https://download.jetbrains.com/go/goland-${version}-aarch64.dmg";
      hash = "sha256-zfdJrXBatvAl3wNMQ3LhF9oOxo1dEyo8wr4lCoFdm9I=";
      # hash = lib.fakeHash;
    };
  });
in
{
  hm = {
    mcp.enable = true;

    home = {
      packages = with pkgs; [
        wget
        opentofu
        spacectl
        goland
        jq
        gotools

        (google-cloud-sdk.withExtraComponents
          (with google-cloud-sdk.components; [
            gke-gcloud-auth-plugin
            gcloud-man-pages
          ])
        )
      ];

      # direnvs
      # todo get relative path injected somehow
      file = {
        "Projects/moov/mf/.envrc".text = ''
          use flake ~/Projects/nix/dotfiles#mf
        '';
      };
    };

    programs = {
      gh= {
        enable = true;
        gitCredentialHelper.enable = false;
        settings.telemetry = "disabled";
      };
      
      zsh = {
        cdpath = [ mfPath ];
      };

      fish = {
        interactiveShellInit = ''
          set -gx CDPATH $CDPATH . ~ ${mfPath}
        '';
      };

      go.env.GOPRIVATE = [ "github.com/moov-io/*" "github.com/moovfinancial/*" ];
    };
  };

  homebrew = {
    casks = [
      "google-drive"
      "linear-linear"
      "notion"
      "1password"
    ];
  };

  system.defaults.LaunchServices.LSQuarantine = lib.mkForce true;
}
