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
        version = "1.27.0";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go${version}.src.tar.gz";
          hash = "sha256-cAJAPXzERSnvbSb2mkSBgmM5Xq18FsBaWAiuBH6+sOU=";
        };
      });
      env.GOPATH = "${config.home.homeDirectory}/go";
    };
  };
}
