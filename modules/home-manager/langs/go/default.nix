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
        version = "1.26.2";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-LpHrtpR6lulDb7KzkmqIAu/mOm03Xf/sT4Kqnb1v1Ds=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
