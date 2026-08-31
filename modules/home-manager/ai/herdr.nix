{ lib, config, pkgs, ... }:
let
  cfg = config.herdr;
  herdr = pkgs.herdr;
in
{
  options.herdr.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable herdr and its opencode integration";
  };

  config = lib.mkIf cfg.enable {
    programs.herdr = {
      enable = true;
      package = herdr;

      settings = {
        onboarding = false;
        experimental.pane_history = true;
        session.resume_agents_on_restore = true;
        ui = {
          agent_panel_sort = "priority";
          prompt_new_tab_name = false;
          sidebar_width = 32;
          toast.delivery = "terminal";
        };
        update.version_check = false;
      };
    };

    # herdr's opencode integrations, taken from the same source revision as
    # the binary instead of `herdr integration install`, which would write
    # them imperatively. Only linked when opencode is enabled.
    xdg.configFile = lib.mkIf config.opencode.enable {
      "opencode/plugins/herdr-agent-state.js".source =
        "${herdr.src}/src/integration/assets/opencode/herdr-agent-state.js";
      "opencode/herdr-tui-session.js".source =
        "${herdr.src}/src/integration/assets/opencode/herdr-tui-session.js";
      "opencode/tui.jsonc".text = builtins.toJSON {
        plugin = [ "./herdr-tui-session.js" ];
      };
    };
  };
}
