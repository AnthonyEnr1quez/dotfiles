{ lib, config, pkgs, ... }:
let
  name = "zed";
in
let
  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption;
in
{
  options.${name} = {
    enable = mkEnableOption name;
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;

      extensions = [
        "docker-compose"
        "dockerfile"
        "git-firefly"
        "csv"
        "log"
        "make"
        "nix"
        "sql"
        "terraform"
      ];

      userSettings = {
        auto_update = false;
        autosave = {
          after_delay = {
            milliseconds = 1000;
          };
        };
        telemetry = {
          metrics = false;
        };
      };
    };
  };
}
