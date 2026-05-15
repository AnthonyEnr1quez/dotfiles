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
      package = pkgs.go_1_26.overrideAttrs (_: rec {
        version = "1.26.3";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-HGRoddCqh5kTMYTtV895/yS97+jIggRwYCqdPW2Rkrg=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
