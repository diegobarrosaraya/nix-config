{
  lib,

  labelFont ? "sans-serif",
  ...
}:
let

  u = code: builtins.fromJSON ''"\u${code}"'';

  registry = {
    "1" = {
      icon = "f111";
      nameless = true;
      # persistent = true;
    };
    "2" = {
      icon = "f0c8";
      nameless = true;
      # persistent = true;
    };
    "3" = {
      icon = "f219";
      nameless = true;
      # persistent = true;
    };
    "4" = {
      icon = "f005";
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
      icon = "e007";
      app = "zen-beta";
      key = "f";
      launch = "zen-beta";
      persistent = true;
      autostart = 2;
    };
    "Files" = {
      icon = "f802";
      launcher = "superfile-launcher";
      key = "e";
      persistent = true;
      autostart = 5;
    };
    "Agents" = {
      icon = "e861";
      persistent = true;
    };
    "Notes" = {
      icon = "e879";
      app = "ZenNotes";
      key = "n";
      launch = "zennotes-desktop";
      persistent = true;
    };
  };
in
{
  inherit registry;

  waybarWorkspaces =
    let
      absorb = "<span font_size='0.1pt'> ";

      label = "<span font_family='${labelFont}'>";
      iconWorkspaces = lib.filterAttrs (_: v: !(v.nameless or false) && v ? icon) registry;
    in
    {
      disable-scroll = false;
      all-outputs = true;
      strip-workspace-numbers = true;
      format = "{icon}{name}</span>";
      format-icons =

        (lib.mapAttrs (_: v: "${u v.icon}${absorb}") iconWorkspaces) // {

          "default" = "${u "f22d"}${label}";
          "focused" = "${u "f192"}${label}";

          "high-priority-named" = lib.attrNames iconWorkspaces;
        };
      persistent-workspaces = lib.mapAttrs' (
        n: v: lib.nameValuePair (if v.nameless or false then "${n}:" else n) [ ]
      ) (lib.filterAttrs (_: v: v.persistent or false) registry);
    };
}
