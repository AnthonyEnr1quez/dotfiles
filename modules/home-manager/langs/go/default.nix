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
        version = "1.27.1";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-TkCKuuEm2Ra2FkYnGT8sVPDjyhMS1pO4bbRfhiqyOLE=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
