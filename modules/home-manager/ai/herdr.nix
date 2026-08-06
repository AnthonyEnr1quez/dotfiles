{ lib, config, pkgs, ... }:
let
  herdr = pkgs.herdr;
in
{
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

  # herdr's opencode integration, taken from the same source revision as the
  # binary instead of `herdr integration install`, which would write it
  # imperatively. Only linked when opencode is enabled.
  xdg.configFile."opencode/plugins/herdr-agent-state.js" = lib.mkIf config.opencode.enable {
    source = "${herdr.src}/src/integration/assets/opencode/herdr-agent-state.js";
  };
}
