{ ... }:
{
  flake.modules.nixos.network-syncthing =
{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.syncthing = {
    enable = true;
    user = "diego";
    dataDir = "/home/diego/.syncthing";
    configDir = "/home/diego/.config/syncthing";

    openDefaultPorts = true;

    guiAddress = "0.0.0.0:8384";

    guiPasswordFile = config.sops.secrets."syncthing-password".path;

    settings = {
      gui = {
        theme = "dark";
        insecureAdminAccess = false;
        user = "diego";
      };

      options = {
        urAccepted = -1;
        crashReportingEnabled = false;
        globalAnnounceEnabled = true;
        localAnnounceEnabled = true;
        natEnabled = true;
        startBrowserEnabled = false;
      };

      devices = {
        "rubi" = {
          id = "O5A33WF-VWBNZ5T-LY27HY7-EIDGGVX-YKCWSDO-PWCZCVV-CTBLHHY-AFQHQQV";
        };
        "grafito" = {
          id = "2MTBMQE-KIQHZKH-PMVOYUO-FWB4LL2-ASNEJQA-C3THXSO-IU5EBYV-DB3N3AB";
        };
        "agata" = {
          id = "PKXTHLD-NZSC2R7-YAQSFP6-X64RLPW-NWOGH2S-KIL2UL6-6HTPQDA-EDJPZAO";
        };
        "jade" = {
          id = "TB4RVRK-FGAN262-IFIOVLA-HDQQCHS-OXVFYXC-TJNLGYC-TXEOISC-QIRK7A2";
        };

      };

      folders = {
        "media-projects" = {
          path = "/srv/media/Repos";
          devices = [ "rubi" ];
        };

        "media-documents" = {
          path = "/srv/media/Documents";
          devices = [
            "grafito"
            "jade"
            "rubi"
          ];
        };

        "media-obsidian" = {
          path = "/srv/media/Obsidian/obsidiana";
          devices = [
            "grafito"
            "jade"
            "rubi"
          ];
        };

        "media-music" = {
          path = "/srv/media/library/music";
          devices = [
            "agata"
            "rubi"
          ];
        };

        "media-pictures" = {
          path = "/srv/media/Pictures";
          devices = [
            "grafito"
            "jade"
            "rubi"
          ];
        };

        "media-books" = {
          path = "/srv/media/library/books";
          devices = [ "rubi" ];
        };


      };
    };
  };

  systemd.services.syncthing = lib.mkIf config.services.syncthing.enable {
    after = [ "srv-media.mount" ];
    requires = [ "srv-media.mount" ];
    # It once reached 17 GB RSS retrying an unwritable folder. Cap it so it
    # cannot starve the rest of the host again. GOMEMLIMIT is a soft target
    # for the Go GC, MemoryHigh throttles, MemoryMax kills (then it restarts).
    environment.GOMEMLIMIT = "3GiB";
    serviceConfig = {
      MemoryHigh = "4G";
      MemoryMax = "6G";
    };
  };

  systemd.tmpfiles.rules = [
    # Synced folders: Syncthing runs as diego, who is in group media. Group
    # needs write (setgid keeps new files in group media) or mkdir fails with
    # "permission denied" and the folder retries forever.
    "d /srv/media/library/music 2770 media media -"
    "d /srv/media/library/books 2770 media media -"
    "d /srv/media/Documents 2770 media media -"
    "d /srv/media/Obsidian 0750 media media -"
    "d /srv/media/Repos 2770 media media -"
    "d /srv/media/Archive 0750 media media -"
    "d /srv/media/Pictures 2770 media media -"
    "d /srv/media/Pictures/Wallpapers 0750 media media -"
    "d /srv/media/Pictures/Photos 0750 media media -"
    "d /srv/media/Pictures/Screenshots 0750 media media -"

  ];

  networking.firewall = {
    allowedTCPPorts = [
      8384
      22000
    ];
    allowedUDPPorts = [
      22000
      21027
    ];
  };
}
  ;
}
