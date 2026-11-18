{ config, ... }@top:
{
  flake.modules.homeManager.desktop-common =
{
  pkgs,
  lib,
  outputs,
  inputs,
  config,
  desktop ? null,
  ...
}:
let
  isGnome = desktop == "gnome";
in
{
  imports = with top.config.flake.modules.homeManager; [
    desktop-common-font
    desktop-common-alacritty
    desktop-common-stylix
    desktop-common-theme-switch
    desktop-common-zen
    desktop-common-playerctl
    desktop-common-mime
    desktop-common-syncthing
    desktop-common-pavucontrol
    desktop-common-obs-studio
    desktop-common-mpv
    desktop-common-swayimg
    desktop-common-udiskie
  ];
  xdg.enable = true;
  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
  # Stylix's gtk target is off, so set the GTK side here. Nix-managed (read-only)
  # files stop kde-gtk-config rewriting breeze icons and a colors.css import
  # that overrides libadwaita's palette.
  gtk = lib.mkIf isGnome {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = if config.colorscheme.mode == "light" then "adw-gtk3" else "adw-gtk3-dark";
    };
    gtk3.extraCss = "";
    gtk4.theme = null;
    gtk4.extraCss = "";
  };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  home.packages = with pkgs; [
  ];

  dconf.settings = lib.mkMerge [
    (lib.mkIf isGnome {
      "org/gnome/shell".always-show-log-out = true;
      "org/gnome/desktop/interface" = {
        enable-animations = true;
        icon-theme = "Adwaita";
        color-scheme = if config.colorscheme.mode == "light" then "prefer-light" else "prefer-dark";
      };
      "org/gnome/desktop/a11y".always-show-universal-access-status = false;
      # Caps Lock as Ctrl; GNOME's own xkb setting overrides the system one.
      "org/gnome/desktop/input-sources".xkb-options = [ "ctrl:nocaps" ];
      # Super+left drag moves, Super+right drag resizes.
      "org/gnome/desktop/wm/preferences" = {
        mouse-button-modifier = "<Super>";
        resize-with-right-button = true;
      };
    })
    (lib.mkIf (!isGnome) {
      "org/gnome/desktop/interface" = {
        color-scheme = lib.mkDefault (
          if config.colorscheme.mode == "light" then "prefer-light" else "prefer-dark"
        );
      } // lib.optionalAttrs (desktop == "sway") {
        cursor-theme = config.stylix.cursor.name;
      };
    })
  ];

};
}
