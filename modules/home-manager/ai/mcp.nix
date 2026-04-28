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
        honeycomb = {
          url = "https://mcp.honeycomb.io/mcp";
          enabled = false;
        };
        linear = {
          url = "https://mcp.linear.app/mcp";
          enabled = false;
        };
        notion = {
          url = "https://mcp.notion.com/mcp";
          enabled = false;
        };
        readable = {
          url = "https://readable.page/mcp";
          enabled = false;
        };
        spacelift = {
          command = "spacectl";
          args = [ "mcp" "server" ];
          enabled = false;
        };
      };
    };
  };
}