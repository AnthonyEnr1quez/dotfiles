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
      package = pkgs.go_1_25.overrideAttrs (_: rec {
        version = "1.25.5";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-IqX9CpHvzSihsFNxBrmVmygEth9Zw3WLUejlQpwalU8=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
