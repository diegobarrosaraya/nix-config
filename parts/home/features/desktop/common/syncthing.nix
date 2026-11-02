{ ... }:
{
  flake.modules.homeManager.desktop-common-syncthing =
{
  config,
  lib,
  pkgs,
  ...
}:

{

  services.syncthing = {
    enable = true;
    settings = {
      devices = {

        cobalto = {
          addresses = [
            "http://syncthing.minerales.network"
          ];
          id = "OBBQD3A-GPIECSP-BYZTCEE-ENGRG6E-Q4QIFPA-RGR74HJ-BOLCQJM-MNKK4AK";
        };
        "grafito" = {
          id = "2MTBMQE-KIQHZKH-PMVOYUO-FWB4LL2-ASNEJQA-C3THXSO-IU5EBYV-DB3N3AB";
        };

      };
      folders = {
        "${config.home.homeDirectory}/Music" = {
          id = "media-music";
          devices = [ "cobalto" ];
        };
        "${config.home.homeDirectory}/Books" = {
          id = "media-books";
          devices = [ "cobalto" ];
        };
        "${config.home.homeDirectory}/Documents" = {
          id = "media-documents";
          devices = [ "cobalto" ];
        };
        "${config.home.homeDirectory}/Notes" = {
          id = "media-obsidian";
          devices = [
            "cobalto"
            "grafito"
          ];
        };
        "${config.home.homeDirectory}/Projects" = {
          id = "media-projects";
          devices = [ "cobalto" ];
        };
        "${config.home.homeDirectory}/Pictures" = {
          id = "media-pictures";
          devices = [ "cobalto" ];
        };
      };
    };
  };

  home.packages = with pkgs; [
    syncthing
  ];

  home.file.".config/syncthing/.stfolder".text = "";

  xdg.userDirs.extraConfig = {
    OBSIDIAN = "${config.home.homeDirectory}/Notes";
  };
  xdg.userDirs.setSessionVariables = false;
};
}
