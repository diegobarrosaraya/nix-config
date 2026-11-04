# Hermes in the same two schemes as rubi: "colors" (tinted-schemes) and the
# local colors-light. Returns hermesHomeFiles entries. The "_" prefix keeps
# import-tree from loading this file as a module.
{ inputs, lib, pkgs }:
let
  yaml = (pkgs.formats.yaml { }).generate;
  base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
  hex = s: lib.mapAttrs (_: v: "#${v}") (lib.filterAttrs (k: _: lib.hasPrefix "base" k) s);
  dark = hex (base16.mkSchemeAttrs (inputs.stylix.inputs.tinted-schemes + "/base16/colors.yaml"));
  light = hex (import ../../../home/modules/_colorschemes/colors-light.nix);

  # Dashboard: the palette triplet drives every derived token; overrides pin
  # the accents to the scheme. Both schemes' blue passes 4.5:1 with white text.
  dashboard = name: label: c: noise: {
    inherit name label;
    description = "${label}, matching rubi's terminal and desktop";
    palette = {
      background = c.base00;
      midground = c.base05;
      foreground = { hex = c.base07; alpha = 0; };
      warmGlow = "rgba(0, 116, 217, 0.12)"; # base0D, the same blue in both
      noiseOpacity = noise;
    };
    colorOverrides = {
      primary = c.base0D;
      primaryForeground = "#ffffff";
      secondary = c.base01;
      secondaryForeground = c.base05;
      muted = c.base01;
      mutedForeground = c.base04;
      accent = c.base0C;
      accentForeground = c.base00;
      destructive = c.base08;
      destructiveForeground = "#ffffff";
      success = c.base0B;
      warning = c.base0A;
      border = c.base02;
      input = c.base02;
      ring = c.base0D;
    };
  };

  # CLI and TUI: one skin, with `light_colors` used on a light terminal, so it
  # follows rubi's light/dark switch without a separate skin.
  skinColors = c: {
    banner_border = c.base0D;
    banner_title = c.base0A;
    banner_accent = c.base09;
    banner_dim = c.base03;
    banner_text = c.base05;
    ui_accent = c.base0D;
    ui_label = c.base0C;
    ui_ok = c.base0B;
    ui_error = c.base08;
    ui_warn = c.base09;
    prompt = c.base05;
    input_rule = c.base02;
    response_border = c.base0D;
    status_bar_bg = c.base01;
    status_bar_text = c.base04;
    status_bar_strong = c.base0D;
    status_bar_dim = c.base03;
    status_bar_good = c.base0B;
    status_bar_warn = c.base0A;
    status_bar_bad = c.base09;
    status_bar_critical = c.base08;
    session_label = c.base0C;
    session_border = c.base03;
    completion_menu_bg = c.base01;
    completion_menu_current_bg = c.base02;
    selection_bg = c.base02;
    shell_dollar = c.base0D;
    voice_status_bg = c.base01;
  };
in
{
  "dashboard-themes/colors.yaml" = yaml "colors.yaml" (dashboard "colors" "Colors" dark 0.4);
  "dashboard-themes/colors-light.yaml" = yaml "colors-light.yaml" (dashboard "colors-light" "Colors Light" light 0);
  "skins/colors.yaml" = yaml "colors-skin.yaml" {
    name = "colors";
    description = "Colors (clrs.cc), dark with a light-terminal overlay";
    colors = skinColors dark;
    light_colors = skinColors light;
  };
}
