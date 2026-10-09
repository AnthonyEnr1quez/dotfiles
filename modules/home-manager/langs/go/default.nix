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
      GOPATH = "${config.home.homeDirectory}/go";
      GOTOOLCHAIN = "local";
    };
  };

  programs = {
    go = {
      enable = true;
      package = pkgs.go_1_27.overrideAttrs (_: rec {
        version = "1.27.2";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-A0ldorpkiU1A9cSZLklFT6eLUGkGBP+Stq//UIG3bmI=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
