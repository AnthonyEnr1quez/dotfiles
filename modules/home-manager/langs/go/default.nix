{ pkgs, lib, ... }: {

  home.sessionPath = [
    "$GOPATH/bin"
  ];

  home.packages = with pkgs; [
    gotestsum
  ];

  programs = {
    go = {
      enable = true;
      package = pkgs.go_1_25.overrideAttrs (_: rec {
        version = "1.25.0";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-S9AekSlyB7+kUOpA1NWpOxtTGl5DhHOyoG4Y4HciciU=";
        };
      });
      goPath = "go";
    };

    zsh.sessionVariables = {
      GOTOOLCHAIN = "local";
    };
  };
}
