{ config, pkgs, lib, ... }: {
  home = {
    packages = with pkgs; [
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
      package = pkgs.go_1_25.overrideAttrs (_: rec {
        version = "1.25.1";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-0BDBCc7pTYDv5oHqtGvepJGskGv0ZYPDLp8NuwvRpZQ=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
