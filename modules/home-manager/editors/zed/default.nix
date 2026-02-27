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
      
      userKeymaps = [
        {
          bindings = {
            cmd-d = "editor::DeleteLine";
          };
        }
      ];

      userSettings = {
        auto_update = false;
        autosave = {
          after_delay = {
            milliseconds = 1000;
          };
        };
        use_system_window_tabs = true;
        telemetry = {
          metrics = false;
        };
        
        buffer_font_family = "Hack Nerd Font";
        buffer_font_size = 14;
        buffer_font_features = {
          calt = false; # disable ligatures
        };
        terminal = {
          font_family = "Hack Nerd Font";
          font_size = 14;
        };
        ui_font_family = "Hack Nerd Font";
        ui_font_size = 14;
      };
    };
  };
}
