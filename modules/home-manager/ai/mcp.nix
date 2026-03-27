{ lib, config, pkgs, ... }: 
let
  name = "mcp";
  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption;
in
{
  options.${name} = {
    enable = mkEnableOption name;
  };

  config = mkIf cfg.enable {
    programs.mcp = {
      enable = true;

      servers = {
        linear = {
          url = " https://mcp.linear.app/mcp";
        };
      };
    };
  };
}