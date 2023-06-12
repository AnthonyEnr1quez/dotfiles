{ config, pkgs, ... }: {
  programs.kitty = {
    enable = true;

    settings = {
      font_family = "Hack Nerd Font";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      font_size = 18;

      strip_trailing_spaces = "smart";
      enable_audio_bell = "no";
      term = "xterm-256color";

      macos_titlebar_color = "background";
      macos_option_as_alt = "yes";
      macos_quit_when_last_window_closed = "yes";
      scrollback_lines = 10000;

      tab_bar_edge = "top";
      tab_bar_style = "separator";
      tab_title_template = "{index}: {title}";
      active_tab_title_template = "{index}: {title.split('/')[-1]}";

      # https://www.ditig.com/256-colors-cheat-sheet
      active_tab_foreground = "#000";
      active_tab_background = "#875fd7";
      active_tab_font_style = "bold-italic";
      inactive_tab_foreground = "#444";
      inactive_tab_background = "#af87d7";
      inactive_tab_font_style = "normal";
    };
  };
}
