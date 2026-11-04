# Hermes in the same two schemes and fonts as rubi: "colors" (tinted-schemes)
# and the local colors-light, with Jost and Fantasque Sans Mono. Returns
# `files` (hermesHomeFiles entries) and `fonts` (served at fontPath by nginx).
# The "_" prefix keeps import-tree from loading this file as a module.
{ inputs, lib, pkgs }:
let
  yaml = (pkgs.formats.yaml { }).generate;

  # The dashboard's CSP allows fonts from 'self', so they are served from the
  # dashboard's own host. Plain Fantasque, not the Nerd Font: 170 KB a file
  # instead of 2.6 MB, and a browser has no use for the icon glyphs.
  fontPath = "/_fonts";
  jost = "${pkgs.jost}/share/fonts/opentype";
  fantasque = "${pkgs.fantasque-sans-mono}/share/fonts/truetype";
  faces = [
    { family = "Jost"; weight = 400; style = "normal"; dir = jost; file = "Jost-400-Book.otf"; }
    { family = "Jost"; weight = 400; style = "italic"; dir = jost; file = "Jost-400-BookItalic.otf"; }
    { family = "Jost"; weight = 500; style = "normal"; dir = jost; file = "Jost-500-Medium.otf"; }
    { family = "Jost"; weight = 600; style = "normal"; dir = jost; file = "Jost-600-Semi.otf"; }
    { family = "Jost"; weight = 700; style = "normal"; dir = jost; file = "Jost-700-Bold.otf"; }
    { family = "Fantasque Sans Mono"; weight = 400; style = "normal"; dir = fantasque; file = "FantasqueSansMono-Regular.ttf"; }
    { family = "Fantasque Sans Mono"; weight = 400; style = "italic"; dir = fantasque; file = "FantasqueSansMono-Italic.ttf"; }
    { family = "Fantasque Sans Mono"; weight = 700; style = "normal"; dir = fantasque; file = "FantasqueSansMono-Bold.ttf"; }
  ];
  fonts = pkgs.linkFarm "hermes-dashboard-fonts" (
    map (f: { name = f.file; path = "${f.dir}/${f.file}"; }) faces
  );
  fontFaceCSS = lib.concatMapStrings (f: ''
    @font-face {
      font-family: "${f.family}";
      font-weight: ${toString f.weight};
      font-style: ${f.style};
      font-display: swap;
      src: url("${fontPath}/${f.file}") format("${if lib.hasSuffix ".otf" f.file then "opentype" else "truetype"}");
    }
  '') faces;
  typography = {
    fontSans = "Jost, system-ui, sans-serif";
    fontDisplay = "Jost, system-ui, sans-serif";
    fontMono = "\"Fantasque Sans Mono\", ui-monospace, monospace";
  };
  pair = import ../../../home/modules/_colorschemes/colors-pair.nix { inherit inputs lib pkgs; };
  hex = lib.mapAttrs (_: v: "#${v}");
  dark = hex pair.dark;
  light = hex pair.light;

  # Dashboard: one theme that follows the browser's prefers-color-scheme, so
  # it switches with darkman on rubi (GTK color-scheme) and with the OS
  # elsewhere. The YAML carries the dark values; the dashboard sets them as
  # inline styles on <html>, so the light block needs !important to win.
  # The palette triplet drives every derived token; overrides pin the accents.
  # Both schemes' blue passes 4.5:1 with white text.
  overrides = c: {
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
  # Same variables the dashboard derives from palette and colorOverrides
  # (web/src/themes/context.tsx: layerVars, overrideVars).
  kebab = lib.replaceStrings lib.upperChars (map (u: "-${lib.toLower u}") lib.upperChars);
  cssVars = c: {
    "--background" = c.base00;
    "--background-base" = c.base00;
    "--midground" = c.base05;
    "--midground-base" = c.base05;
    "--foreground" = "transparent";
    "--foreground-base" = c.base07;
  } // lib.mapAttrs' (k: v: lib.nameValuePair "--color-${kebab k}" v) (overrides c);
  lightCSS = ''
    :root { color-scheme: dark; }
    @media (prefers-color-scheme: light) {
      :root {
        color-scheme: light;
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "    ${k}: ${v} !important;\n") (cssVars light))}  }
    }
  '';
  dashboard = {
    name = "colors";
    label = "Colors";
    description = "Colors and colors-light, following the system light/dark setting";
    inherit typography;
    customCSS = fontFaceCSS + lightCSS;
    palette = {
      background = dark.base00;
      midground = dark.base05;
      foreground = { hex = dark.base07; alpha = 0; };
      noiseOpacity = 0;
    };
    colorOverrides = overrides dark;
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
  inherit fonts fontPath;
  files = {
    "dashboard-themes/colors.yaml" = yaml "colors.yaml" dashboard;
    "skins/colors.yaml" = yaml "colors-skin.yaml" {
      name = "colors";
      description = "Colors (clrs.cc), dark with a light-terminal overlay";
      colors = skinColors dark;
      light_colors = skinColors light;
    };
  };
}
