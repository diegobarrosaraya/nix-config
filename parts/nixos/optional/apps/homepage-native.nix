{ ... }:
{
  flake.modules.nixos.apps-homepage-native =
{
  config,
  lib,
  pkgs,
  ...
}:

{

  environment.systemPackages = with pkgs; [
    glances
  ];

  services.glances = {
    enable = true;
    port = 61208;
    openFirewall = true;
  };

  networking.firewall = {
    allowedTCPPorts = [
      61208
    ];
  };

  services.homepage-dashboard = {
    enable = true;
    openFirewall = true;
    allowedHosts = "home.minerales.network";
    listenPort = 8082;

    settings = {
      title = "Cobalto Media Server";
      headerStyle = "boxed";

      theme = if config.services.cobaltoTheme.mode == "light" then "light" else "dark";
      color = "slate";
      favicon = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 576 512'%3E%3Cstyle%3E@media (prefers-color-scheme: dark){path{fill:%23d4d4d8}}%3C/style%3E%3Cpath fill='%23171717' d='M575.8 255.5c0 18-15 32.1-32 32.1h-32l.7 160.2c0 2.7-.2 5.4-.5 8.1V472c0 22.1-17.9 40-40 40H456c-1.1 0-2.2 0-3.3-.1c-1.4 .1-2.8 .1-4.2 .1H416 392c-22.1 0-40-17.9-40-40V448 384c0-17.7-14.3-32-32-32H256c-17.7 0-32 14.3-32 32v64 24c0 22.1-17.9 40-40 40H160 128.1c-1.5 0-3-.1-4.5-.2c-1.2 .1-2.4 .2-3.6 .2H104c-22.1 0-40-17.9-40-40V360c0-.9 0-1.9 .1-2.8V287.6H32c-18 0-32-14-32-32.1c0-9 3-17 10-24L266.4 8c7-7 15-8 22-8s15 2 21 7L564.8 231.5c8 7 12 15 11 24z'/%3E%3C/svg%3E";
      iconStyle = "theme";

      layout = {
        "Media Services" = {
          style = "row";
          columns = 2;
          icon = "mdi-movie";
        };
        "AI & LLM" = {
          style = "row";
          columns = 2;
          icon = "mdi-robot";
        };
        "Notes" = {
          style = "row";
          columns = 2;
          icon = "mdi-note-text";
        };
        "System Tools" = {
          style = "row";
          columns = 2;
          icon = "mdi-cog";
        };
        "Home Automation" = {
          style = "row";
          columns = 2;
          icon = "mdi-home-automation";
        };
        "Downloads & Automation" = {
          style = "row";
          columns = 4;
          icon = "mdi-download-circle";
          initiallyCollapsed = true;
        };
      };

      customCSS = ''
        :root {
          --cobalto-surface: ${config.services.cobaltoTheme.surface};
          --cobalto-primary: ${config.services.cobaltoTheme.base16Scheme.base0D};
        }
        .service-group { margin-bottom: 2rem; }
        .widget-container { backdrop-filter: blur(10px); }
      '';
    };

    services = [
      {
        "Media Services" = [
          {
            "Jellyfin" = {
              icon = "mdi-play-circle";
              href = "http://jellyfin.minerales.network";
              description = "Media streaming server";
              widget = {
                type = "jellyfin";
                url = "http://localhost:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
              };
            };
          }
          {
            "Jellyseerr" = {
              icon = "mdi-movie-open";
              href = "http://jellyseerr.minerales.network";
              description = "Media request portal";
              widget = {
                type = "jellyseerr";
                url = "http://localhost:5055";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_API_KEY}}";
              };
            };
          }
        ];
      }
      {
        "Downloads & Automation" = [
          {
            "Transmission" = {
              icon = "mdi-arrow-down-circle";
              href = "http://transmission.minerales.network";
              description = "Native BitTorrent client";
              widget = {
                type = "transmission";
                url = "http://localhost:8080";
              };
            };
          }
          {
            "Aria2" = {
              icon = "mdi-download";
              href = "http://aria2.minerales.network";
              description = "Download server";
              widget = {
                type = "aria2";
                url = "http://localhost:6800";
                secret = "{{HOMEPAGE_VAR_ARIA2_RPC_SECRET}}";
              };
            };
          }
          {
            "Tdarr" = {
              icon = "mdi-cog-refresh";
              href = "http://tdarr.minerales.network";
              description = "Transcoding automation";
              widget = {
                type = "tdarr";
                url = "http://localhost:8265";
                key = "{{HOMEPAGE_VAR_TDARR_API_KEY}}";
              };
            };
          }
          {
            "Prowlarr" = {
              icon = "mdi-magnify";
              href = "http://prowlarr.minerales.network";
              description = "Indexer manager";
              widget = {
                type = "prowlarr";
                url = "http://localhost:9696";
                key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
              };
            };
          }
          {
            "Sonarr" = {
              icon = "mdi-television";
              href = "http://sonarr.minerales.network";
              description = "TV show manager";
              widget = {
                type = "sonarr";
                url = "http://localhost:8989";
                key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
              };
            };
          }
          {
            "Radarr" = {
              icon = "mdi-movie";
              href = "http://radarr.minerales.network";
              description = "Movie manager";
              widget = {
                type = "radarr";
                url = "http://localhost:7878";
                key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
              };
            };
          }
          {
            "Lidarr" = {
              icon = "mdi-music-note";
              href = "http://lidarr.minerales.network";
              description = "Music manager";
              widget = {
                type = "lidarr";
                url = "http://localhost:8686";
                key = "{{HOMEPAGE_VAR_LIDARR_API_KEY}}";
              };
            };
          }
          {
            "Bazarr" = {
              icon = "mdi-subtitles";
              href = "http://bazarr.minerales.network";
              description = "Subtitle manager";
              widget = {
                type = "bazarr";
                url = "http://localhost:6767";
                key = "{{HOMEPAGE_VAR_BAZARR_API_KEY}}";
              };
            };
          }
        ];
      }
      {
        "AI & LLM" = [
          {
            "llama.cpp" = {
              icon = "mdi-brain";
              href = "http://localhost:11435";
              description = "Vulkan-accelerated LLM server";
            };
          }
        ];
      }
      {
        "Notes" = [
          {
            "ZenNotes" = {
              icon = "/zennotes-icon.svg";
              href = "https://notes.minerales.network";
              description = "Markdown notes web UI";
            };
          }
        ];
      }
      {
        "System Tools" = [
          {
            "Syncthing" = {
              icon = "mdi-folder-sync";
              href = "http://syncthing.minerales.network";
              description = "File synchronization";
              widget = {
                type = "syncthing";
                url = "https://syncthing.minerales.network";
                key = "{{HOMEPAGE_VAR_SYNCTHING_API_KEY}}";
              };
            };
          }
        ];
      }
      {
        "Home Automation" = [
          {
            "Snapcast" = {
              icon = "mdi-speaker-multiple";
              href = "http://snapcast.minerales.network";
              description = "Multi-room audio server";
            };
          }
        ];
      }
    ];

    widgets = [
      {
        search = {
          provider = "custom";
          url = "https://lite.duckduckgo.com/lite?q=";
          target = "_blank";
        };
      }
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        resources = {
          label = "Storage";
          disk = "/srv/media";
        };
      }
    ];

    bookmarks = [
      {
        "Development" = [
          {
            "nix-config" = [
              {
                href = "https://github.com/DiegoBarrosA/nix-config";
                description = "NixOS configuration repository";
                icon = "si-github";
              }
            ];
          }
        ];
      }
      {
        "Media" = [
          {
            "YouTube" = [
              {
                href = "https://youtube.com";
                description = "Video streaming";
                icon = "si-youtube";
              }
            ];
          }
          {
            "Spotify" = [
              {
                href = "https://spotify.com";
                description = "Music streaming";
                icon = "si-spotify";
              }
            ];
          }
        ];
      }
    ];
  };

  systemd.services.homepage-secrets = {
    description = "Generate Homepage Dashboard secrets env file";
    before = [ "homepage-dashboard.service" ];
    requiredBy = [ "homepage-dashboard.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /etc/homepage-dashboard
      {
        echo "# Homepage Dashboard API Keys - generated at service start"
        for secret_name in jellyfin-api-key prowlarr-api-key sonarr-api-key radarr-api-key lidarr-api-key bazarr-api-key; do
          env_name="HOMEPAGE_VAR_$(echo "$secret_name" | tr '[:lower:]-' '[:upper:]_')"
          secret_file="/run/secrets/$secret_name"
          if [ -f "$secret_file" ] && [ -s "$secret_file" ]; then
            echo "$env_name=$(cat "$secret_file" | tr -d '\n')"
          else
            echo "$env_name="
          fi
        done
        SYNCTHING_CONFIG="/home/diego/.config/syncthing/config.xml"
        if [ -f "$SYNCTHING_CONFIG" ] && [ -s "$SYNCTHING_CONFIG" ]; then
          API_KEY=$(grep '<apikey>' "$SYNCTHING_CONFIG" | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
          echo "HOMEPAGE_VAR_SYNCTHING_API_KEY=$API_KEY"
        else
          echo "HOMEPAGE_VAR_SYNCTHING_API_KEY="
        fi
        nextauth_file="/run/secrets/nextauth-secret"
        if [ -f "$nextauth_file" ] && [ -s "$nextauth_file" ]; then
          echo "NEXTAUTH_SECRET=$(cat "$nextauth_file" | tr -d '\n')"
        else
          echo "NEXTAUTH_SECRET="
        fi
      } > /etc/homepage-dashboard/secrets.env
      chmod 600 /etc/homepage-dashboard/secrets.env
    '';
  };

  systemd.services.homepage-dashboard = {
    after = [ "homepage-secrets.service" ];
    serviceConfig.EnvironmentFile = "/etc/homepage-dashboard/secrets.env";
  };
}
  ;
}
