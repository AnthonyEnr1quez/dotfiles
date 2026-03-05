{ config, pkgs, lib, ... }:
let
  mfPath = "${config.user.home}/Projects/moov/mf";

  goland = pkgs.jetbrains.goland.overrideAttrs (_: rec {
    version = "2025.3.3";
    src = pkgs.fetchurl {
      url = "https://download.jetbrains.com/go/goland-${version}-aarch64.dmg";
      hash = "sha256-v98kJnaxyAvo5aNgmgU4tR2BSR0etZgxxP9abJ6vBb4=";
      # hash = lib.fakeHash;
    };
  });
in
{
  hm = {
    home = {
      packages = with pkgs; [
        gh
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
      "docker-desktop"
      "google-drive"
      "linear-linear"
      "notion"
      "1password"
    ];
  };

  system.defaults.LaunchServices.LSQuarantine = lib.mkForce true;
}
