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
          disabled = true;
        };
        linear = {
          url = "https://mcp.linear.app/mcp";
          disabled = true;
        };
        notion = {
          url = "https://mcp.notion.com/mcp";
          disabled = true;
        };
        readable = {
          url = "https://readable.page/mcp";
          disabled = true;
        };
        spacelift = {
          command = "spacectl";
          args = [ "mcp" "server" ];
          disabled = true;
        };

        # https://github.com/anomalyco/opencode/issues/8581
        # bigquery = {
        #   url = "https://bigquery.googleapis.com/mcp";
        #   enabled = false;
        # };
        # gke = {
        #   url = "https://container.googleapis.com/mcp";
        #   enabled = false;
        # };
      };
    };
  };
}
