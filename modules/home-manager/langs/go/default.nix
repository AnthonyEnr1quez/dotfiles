{ config, pkgs, lib, ... }: {
  home = {
    packages = with pkgs; [
      gotest
      gotestsum
    ];
    sessionPath = [
      "$GOPATH/bin"
    ];
    sessionVariables = {
      GOTOOLCHAIN = "local";
    };
  };

  programs = {
    go = {
      enable = true;
      package = pkgs.go_1_26.overrideAttrs (_: rec {
        version = "1.26.0";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-yRMqih9r0qpKrR10uCMdlSdJUEg6SVBlfubFbm6Bd5A=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
