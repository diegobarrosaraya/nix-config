{ ... }:
{
  flake.modules.homeManager.desktop-sway-mako =
{ config, pkgs, ... }:
let
  inherit (config.colorscheme) colors;
  inherit (config.stylix) fonts;
  # mako's D-Bus service is Name=org.freedesktop.Notifications. In the user
  # profile it would start mako under niri and take the name from yami.
  # package = null keeps this config and skips home-manager's dbus.packages
  # link; the bin-only package is what actually lands on PATH. sway starts
  # the daemon itself.
  mako = pkgs.runCommand "mako-bin" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.mako}/bin/mako $out/bin/mako
    ln -s ${pkgs.mako}/bin/makoctl $out/bin/makoctl
  '';
in
{
  services.mako = {
    enable = true;
    package = null;
    settings = {
      font = "${fonts.sansSerif.name} 14";
      max-visible = 5;
      sort = "-time";
      layer = "overlay";
      anchor = "top-right";
      margin = "10";
      padding = "12";
      width = 350;
      height = 120;
      border-size = 2;
      border-radius = 0;
      icons = 1;
      icon-path = "/usr/share/icons/Papirus-Dark";
      max-icon-size = 48;
      default-timeout = 5000;
      ignore-timeout = 0;
      background-color = "#${colors.base00}FF";
      text-color = "#${colors.base05}";
      border-color = "#${colors.base02}";
      progress-color = "over #${colors.base0C}";

      "urgency=low" = {
        background-color = "#${colors.base00}FF";
        text-color = "#${colors.base04}";
        border-color = "#${colors.base01}";
        default-timeout = 3000;
      };

      "urgency=normal" = {
        background-color = "#${colors.base00}FF";
        text-color = "#${colors.base05}";
        border-color = "#${colors.base0D}";
        default-timeout = 5000;
      };

      "urgency=critical" = {
        background-color = "#${colors.base0F}";
        text-color = "#${colors.base00}";
        border-color = "#${colors.base08}";
        default-timeout = 0;
      };

      "category=volume" = {
        default-timeout = 1500;
        height = 60;
        border-color = "#${colors.base0C}";
      };

      "category=brightness" = {
        default-timeout = 1500;
        height = 60;
        border-color = "#${colors.base0A}";
      };
    };
  };

  home.packages = [ mako ];
};
}
