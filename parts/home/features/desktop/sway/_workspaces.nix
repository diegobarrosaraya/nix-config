{
  lib,

  labelFont ? "sans-serif",
  colors,
  ...
}:
let

  # Code points above ffff need a JSON surrogate pair (U+100000 is dbc0 dc00).
  u =
    code:
    let
      n = (builtins.fromTOML "x = 0x${code}").x;
      v = n - 65536;
      hex = x: lib.toLower (lib.toHexString x);
    in
    if n > 65535 then
      builtins.fromJSON "\"\\u${hex (55296 + v / 1024)}\\u${hex (56320 + lib.mod v 1024)}\""
    else
      builtins.fromJSON "\"\\u${code}\"";

  registry = {
    "1" = {
      icon = "ef4a";
      nameless = true;
      # persistent = true;
    };
    "2" = {
      icon = "eb36";
      nameless = true;
      # persistent = true;
    };
    "3" = {
      icon = "ead5";
      nameless = true;
      # persistent = true;
    };
    "4" = {
      icon = "e838";
      nameless = true;
      # persistent = true;
    };
    "5" = {
      nameless = true;
    };
    "6" = {
      nameless = true;
    };
    "7" = {
      nameless = true;
    };
    "8" = {
      nameless = true;
    };
    "9" = {
      nameless = true;
    };
    "10" = {
      nameless = true;
    };
    "Web" = {
      icon = "e87a";
      app = "zen";
      key = "f";
      launch = "zen";
      persistent = true;
      autostart = 2;
    };
    "Files" = {
      icon = "ea85";
      launcher = "superfile-launcher";
      key = "e";
      persistent = true;
      autostart = 5;
    };
    "Agents" = {
      icon = "e65f"; # Material auto_awesome
      persistent = true;
    };
    "Notes" = {
      icon = "e9f4";
      app = "zennotes";
      key = "n";
      launch = "zennotes-desktop";
      persistent = true;
    };
  };
in
{
  inherit registry;

  # Bracket style (see the mockup): the focused workspace is "[ name ]" in the accent, the
  # rest are dim " name". The trailing bracket sits outside the span, so the CSS button
  # colour decides it: accent when focused, the bar background (invisible) otherwise.
  waybarWorkspaces = {
    disable-scroll = false;
    all-outputs = true;
    strip-workspace-numbers = true;
    format = "{icon}{name}</span>]";
    format-icons = {
      default = "<span foreground='#${colors.base04}'> ";
      focused = "<span foreground='#${colors.base0C}' weight='bold'>[";
      urgent = "<span foreground='#${colors.base08}'> ";
    };
    persistent-workspaces = lib.mapAttrs' (
      n: v: lib.nameValuePair (if v.nameless or false then "${n}:" else n) [ ]
    ) (lib.filterAttrs (_: v: v.persistent or false) registry);
  };
}
