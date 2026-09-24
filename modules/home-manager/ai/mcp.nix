{ lib, config, osConfig, ... }:
let
  name = "mcp";
  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption;
in
{
  options.${name} = {
    enable = mkEnableOption "MCP servers for OpenCode";
  };

  config = mkIf (cfg.enable && config.opencode.enable) {
    programs.opencode.settings.mcp = {
      honeycomb = mkIf (osConfig.sops.secrets ? honeycomb-api-key) {
        type = "remote";
        url = "https://mcp.honeycomb.io/mcp";
        enabled = true;
        oauth = false;
        headers.Authorization = "Bearer {file:${osConfig.sops.secrets.honeycomb-api-key.path}}";
      };
      incident-io = {
        type = "remote";
        url = "https://mcp.incident.io/mcp";
        enabled = false;
      };
      linear = mkIf (osConfig.sops.secrets ? linear-api-key) {
        type = "remote";
        url = "https://mcp.linear.app/mcp";
        enabled = true;
        oauth = false;
        headers.Authorization = "Bearer {file:${osConfig.sops.secrets.linear-api-key.path}}";
      };
      notion = {
        type = "remote";
        url = "https://mcp.notion.com/mcp";
        enabled = false;
      };
      postman = mkIf (osConfig.sops.secrets ? postman-api-key) {
        type = "remote";
        url = "https://mcp.postman.com/mcp";
        enabled = true;
        oauth = false;
        headers.Authorization = "Bearer {file:${osConfig.sops.secrets.postman-api-key.path}}";
      };
      readable = {
        type = "remote";
        url = "https://readable.page/mcp";
        enabled = false;
      };
      spacelift = {
        type = "local";
        command = [ "spacectl" "mcp" "server" ];
        enabled = false;
      };

      # https://github.com/anomalyco/opencode/issues/8581
      # bigquery = {
      #   type = "remote";
      #   url = "https://bigquery.googleapis.com/mcp";
      #   enabled = false;
      # };
      # gke = {
      #   type = "remote";
      #   url = "https://container.googleapis.com/mcp";
      #   enabled = false;
      # };
    };
  };
}
