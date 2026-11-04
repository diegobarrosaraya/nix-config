{ ... }:
{
  flake.modules.homeManager.cli-superfile =
    { config, ... }:
    let
      # Stylix palette on desktops, the standalone colorscheme module where
      # stylix is not loaded (e.g. nix-on-droid). Both are mkSchemeAttrs.
      hasStylix = config.lib ? stylix;
      palette = if hasStylix then config.lib.stylix.colors else config.colorscheme.colors;
      c = palette.withHashtag;
      polarity = if hasStylix then config.stylix.polarity else config.colorscheme.mode;
    in
    {
      programs.superfile = {
        enable = true;
        # The settings file is generated, so superfile must not warn about keys
        # we leave at their defaults, and it must not try to self-update.
        settings = {
          theme = "stylix";
          nerdfont = true;
          zoxide_support = true;
          auto_check_update = false;
          ignore_missing_fields = true;
        };

        pinnedFolders =
          (map (d: {
            name = d;
            location = "${config.home.homeDirectory}/${d}";
          }) [ "Documents" "Downloads" "Pictures" "Projects" ])
          ++ [
            { name = "Cobalto media"; location = "/mnt/cobalto/media"; }
            { name = "Cobalto storage"; location = "/mnt/cobalto/storage"; }
          ];

        # Stylix has no superfile target, so build the theme from its palette.
        themes.stylix = {
          code_syntax_highlight = if polarity == "light" then "github" else "monokai";

          full_screen_fg = c.base05;
          full_screen_bg = c.base00;

          gradient_color = [ c.base0D c.base0E ];

          file_panel_fg = c.base05;
          file_panel_bg = c.base00;
          file_panel_border = c.base03;
          file_panel_border_active = c.base0D;
          file_panel_top_directory_icon = c.base0B;
          file_panel_top_path = c.base0D;
          file_panel_item_selected_fg = c.base0D;
          file_panel_item_selected_bg = c.base00;

          footer_fg = c.base05;
          footer_bg = c.base00;
          footer_border = c.base03;
          footer_border_active = c.base0B;

          sidebar_fg = c.base05;
          sidebar_bg = c.base00;
          sidebar_title = c.base0C;
          sidebar_border = c.base00;
          sidebar_border_active = c.base08;
          sidebar_item_selected_fg = c.base0D;
          sidebar_item_selected_bg = c.base00;
          sidebar_divider = c.base03;

          modal_fg = c.base05;
          modal_bg = c.base00;
          modal_border_active = c.base03;
          modal_cancel_fg = c.base00;
          modal_cancel_bg = c.base08;
          modal_confirm_fg = c.base00;
          modal_confirm_bg = c.base0C;

          help_menu_hotkey = c.base0C;
          help_menu_title = c.base08;

          cursor = c.base06;
          correct = c.base0B;
          error = c.base08;
          hint = c.base0C;
          cancel = c.base08;
        };
      };
    };
}
