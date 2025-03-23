{ config, pkgs, lib, ... }: {
  hm = {
    home = {
      packages = with pkgs; [
        gh
        wget
        opentofu
        blackbox
        jetbrains.goland
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

          # fix ld linked errors
          # https://stackoverflow.com/questions/71112682/ld-warning-dylib-was-built-for-newer-macos-version-11-3-than-being-linked-1
          # ld: warning: object file (/Users/anthony.enriquez/go/pkg/mod/github.com/confluentinc/confluent-kafka-go/v2@v2.2.0/kafka/librdkafka_vendor/librdkafka_darwin_arm64.a(libcommon-lib-der_ec_key.o)) was built for newer macOS version (12.0) than being linked (11.0)
          # for some reason, cant override this directly in the flake
          export MACOSX_DEPLOYMENT_TARGET=14.0
        '';
      };
    };

    programs = {
      zsh = {
        cdpath = [
          "${config.user.home}/Projects/moov/mf"
        ];
      };

      go.goPrivate = [ "github.com/moov-io/*" "github.com/moovfinancial/*" ];
    };
  };

  homebrew = {
    casks = [
      "docker"
      "google-drive"
      "linear-linear"
      "notion"
      "1password"
    ];
  };

  system.defaults.LaunchServices.LSQuarantine = lib.mkForce true;
}
