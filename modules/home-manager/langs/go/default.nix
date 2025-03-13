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
        version = "1.24.1";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-gkTr9GxlYH2xAiK1gGrrMcH8+JecG2sS9gxnfpo8BlY=";
        };
      });
      goPath = "go";
    };

    zsh.sessionVariables = {
      GOTOOLCHAIN = "local";
    };
  };
}
