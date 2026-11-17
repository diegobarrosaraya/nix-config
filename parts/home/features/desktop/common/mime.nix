{ ... }:
{
  flake.modules.homeManager.desktop-common-mime =
{ config, ... }: {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {

      "text/html" = [ "zen.desktop" ];
      "x-scheme-handler/http" = [ "zen.desktop" ];
      "x-scheme-handler/https" = [ "zen.desktop" ];
      "x-scheme-handler/about" = [ "zen.desktop" ];
      "x-scheme-handler/unknown" = [ "zen.desktop" ];
      "application/xhtml+xml" = [ "zen.desktop" ];
      "application/x-extension-htm" = [ "zen.desktop" ];
      "application/x-extension-html" = [ "zen.desktop" ];
      "application/x-extension-shtml" = [ "zen.desktop" ];
      "application/x-extension-xhtml" = [ "zen.desktop" ];
      "application/x-extension-xht" = [ "zen.desktop" ];

      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];

      "application/zip" = [ "xarchiver.desktop" ];
      "application/pdf" = [ "org.pwmt.zathura.desktop" ];

    };
  };
};
}
