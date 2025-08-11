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
      package = pkgs.go_1_24.overrideAttrs (_: rec {
        version = "1.24.6";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-4ctVgqq1iGaLwEwH3hhogHD2uMmyqvNh+CHhm9R8/b0=";
        };
      });
      goPath = "go";
    };

    zsh.sessionVariables = {
      GOTOOLCHAIN = "local";
    };
  };
}
