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
        version = "1.24.5";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-dP2wnyNS4rJbeUPlaDbJtHNj0o3sHItWxKlXDzC49Z8=";
        };
      });
      goPath = "go";
    };

    zsh.sessionVariables = {
      GOTOOLCHAIN = "local";
    };
  };
}
