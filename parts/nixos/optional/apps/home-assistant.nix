{ ... }:
{
  flake.modules.nixos.apps-home-assistant =
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # TCL Google TV "cuarzo" (admin console name; was bedroom-tv). Reached over
  # Tailscale by IP: it does not depend on MagicDNS and keeps the tailnet name
  # out of this public repo.
  tvHost = "100.64.82.96";

  # Power, volume, apps and keys go through the Android TV Remote integration
  # (UI-only, no YAML: add it with host ${tvHost}, enter the code the TV shows,
  # name the device "cuarzo" so the entities are media_player.cuarzo and
  # remote.cuarzo). ADB is used only for the backlight, which the remote
  # protocol cannot set. Do not also add the androidtv (ADB) integration:
  # two media players for one TV give duplicate entities and conflicting state.
  # One-time step that cannot be declared: accept "Allow USB debugging?" on
  # the TV (tick "always allow") for the hass user's adb key.
  tvctl = pkgs.writeShellScript "tvctl" ''
    set -eu
    export HOME=${config.services.home-assistant.configDir}
    export ANDROID_ADB_SERVER_PORT=5038
    adb=${pkgs.android-tools}/bin/adb
    tv=${tvHost}:5555
    ${pkgs.coreutils}/bin/timeout 8 "$adb" connect "$tv" >/dev/null
    exec ${pkgs.coreutils}/bin/timeout 10 "$adb" -s "$tv" shell "$@"
  '';
in
{

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
      publish-workstation = true;
    };
  };

  services.matter-server = {
    enable = true;
  };

  services.home-assistant = {
    enable = true;

    extraComponents = [
      "default_config"
      "met"
      "esphome"
      "androidtv_remote"
      "cast"
    ];
    extraPackages = ps: with ps; [

      music-assistant-client
      python-miio
      python-otbr-api
      pyatv
      pyswitchbot
      yeelight
      gtts
      reolink-aio
    ] ++ [ pkgs.ffmpeg-headless ];
    customComponents = [
      pkgs."home-assistant-custom-components".tuya_local
    ];
    config = {
      default_config = {};

      frontend = {
        themes = {
          ${config.services.cobaltoTheme.scheme} =
            let
              theme = config.services.cobaltoTheme;
            in
            {
              primary-color = theme.base16Scheme.base0D;
              accent-color = theme.base16Scheme.base0E;
              dark-primary-color = theme.base16Scheme.base0D;
              light-primary-color = theme.base16Scheme.base01;

              primary-text-color = theme.base16Scheme.base05;
              secondary-text-color = theme.base16Scheme.base04;
              text-primary-color = theme.base16Scheme.base00;
              disabled-text-color = theme.base16Scheme.base03;

              primary-background-color = theme.base16Scheme.base00;
              secondary-background-color = theme.surface;
              divider-color = theme.base16Scheme.base02;

              "app-header-background-color" = theme.base16Scheme.base01;
              "app-header-text-color" = theme.base16Scheme.base05;
              "sidebar-background-color" = theme.base16Scheme.base01;
              "sidebar-icon-color" = theme.base16Scheme.base04;
              "sidebar-text-color" = theme.base16Scheme.base05;
              "sidebar-selected-icon-color" = theme.base16Scheme.base0D;
              "sidebar-selected-text-color" = theme.base16Scheme.base0D;

              "card-background-color" = theme.surface;
              "ha-card-background" = theme.surface;
              "ha-card-border-radius" = "10px";
              "paper-card-background-color" = theme.surface;

              "label-badge-background-color" = theme.base16Scheme.base01;
              "state-icon-color" = theme.base16Scheme.base0D;
              "switch-checked-color" = theme.base16Scheme.base0D;

              "error-color" = theme.base16Scheme.base08;
              "warning-color" = theme.base16Scheme.base0A;
              "success-color" = theme.base16Scheme.base0B;
              "info-color" = theme.base16Scheme.base0D;
            };
        };
      };

      camera = [
        {
          platform = "ffmpeg";
          name = "Xiaomi C200";
          input = "rtsp://127.0.0.1:8557/xiaomi_cam";
        }
        {
          platform = "ffmpeg";
          name = "Reolink E1";
          input = "rtsp://127.0.0.1:8557/reolink_e1";
        }
      ];

      ffmpeg = {
        ffmpeg_bin = "${pkgs.ffmpeg-headless}/bin/ffmpeg";
      };

      homeassistant = {
        external_url = "https://homeassistant.minerales.network";
        internal_url = "https://homeassistant.minerales.network";
      };

      http = {
        server_host = "127.0.0.1";
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" "::1" ];
      };

      systemmonitor = {
        resources = [
          { type = "disk_use_percent"; arg = "/"; }
          { type = "disk_use_percent"; arg = "/nix/storage"; }
          { type = "disk_use_percent"; arg = "/srv/media"; }
          { type = "memory_use_percent"; }
          { type = "processor_use"; }
          { type = "processor_temperature"; }
          { type = "network_in"; arg = "enp6s0"; }
          { type = "network_out"; arg = "enp6s0"; }
          { type = "ipv4_address"; arg = "enp6s0"; }
          { type = "last_boot"; }
        ];
      };

      jellyfin = {
        host = "127.0.0.1";
        http_port = 8096;
      };

      music_assistant = {};

      snapcast = {
        host = "127.0.0.1";
        port = 1705;
      };

      switchbot = {};

      matter = {
        url = "http://localhost:5580";
      };

      qbittorrent = {
        host = "127.0.0.1";
        port = 8080;
        username = "admin";
        password = "";
      };

      syncthing = {
        url = "http://127.0.0.1:8384";
        api_key = "";
      };

      sonarr = {
        url = "http://127.0.0.1:8989";
        api_key = "";
      };

      radarr = {
        url = "http://127.0.0.1:7878";
        api_key = "";
      };

      lidarr = {
        url = "http://127.0.0.1:8686";
        api_key = "";
      };

      prowlarr = {
        url = "http://127.0.0.1:9696";
        api_key = "";
      };

      bazarr = {
        url = "http://127.0.0.1:6767";
        api_key = "";
      };

      tailscale = {};

      # TCL Google TV "cuarzo": backlight only, with adb over Tailscale (see
      # tvctl). UNVERIFIED on the live panel: that writing picture_backlight
      # changes the picture immediately. The TV has no usable Android
      # screen_brightness.
      shell_command = {
        tv_backlight = "${tvctl} settings put global picture_backlight {{ level }}";
      };

      # State read-back, polled every 60 s. An unreachable TV reads as 0.
      command_line = [
        {
          sensor = {
            name = "TV Backlight Level";
            unique_id = "cuarzo_backlight_level";
            command = "${tvctl} settings get global picture_backlight | ${pkgs.coreutils}/bin/tr -dc 0-9";
            unit_of_measurement = "%";
            scan_interval = 60;
            command_timeout = 25;
          };
        }
      ];

      # Backlight as a dimmable light so HomeKit and Alexa get a slider (they
      # have none for media_player). Off sets the backlight to 0: the screen
      # goes dark while the TV keeps playing.
      template = [{
        light = [{
          name = "TV Backlight";
          unique_id = "cuarzo_backlight";
          icon = "mdi:television-ambient-light";
          state = "{{ states('sensor.tv_backlight_level') | int(0) > 0 }}";
          level = "{{ (states('sensor.tv_backlight_level') | int(0) * 255 / 100) | round(0) | int }}";
          turn_on = [{
            action = "shell_command.tv_backlight";
            data.level = 100;
          }];
          turn_off = [{
            action = "shell_command.tv_backlight";
            data.level = 0;
          }];
          set_level = [{
            action = "shell_command.tv_backlight";
            data.level = "{{ (brightness / 255 * 100) | round(0) | int }}";
          }];
        }];
      }];

      alexa = {
        smart_home = {
          endpoint = "https://alexa-homeassistant.minerales.network/api/alexa/smart_home";
          filter = {
            include_domains = [
              "alarm_control_panel"
              "binary_sensor"
              "climate"
              "cover"
              "fan"
              "humidifier"
              "light"
              "lock"
              "media_player"
              "sensor"
              "switch"
              "vacuum"
            ];
          };
        };
      };

      homekit = [{
        filter = {
          include_domains = [
            "alarm_control_panel"
            "binary_sensor"
            "climate"
            "cover"
            "fan"
            "humidifier"
            "light"
            "lock"
            "media_player"
            "sensor"
            "switch"
            "vacuum"
          ];
        };
      }];
    };
  };

  services.home-assistant.lovelaceConfig = {
    title = "Cobalto Home";

    theme = config.services.cobaltoTheme.scheme;
    views = [

      {
        title = "Home";
        path = "home";
        icon = "mdi:home";
        cards = [
          {
            type = "weather-forecast";
            entity = "weather.forecast_home";
            show_current = true;
            show_forecast = true;
          }
          {
            type = "glance";
            title = "People";
            entities = [
              "person.diego_barros"
              "person.adriana"
            ];
          }
          {
            type = "entities";
            title = "Lights";
            entities = [
              { entity = "light.192_168_1_49"; name = "Bedroom"; }
              { entity = "light.192_168_1_14"; name = "Office"; }
              { entity = "light.192_168_1_16"; name = "Kitchen"; }
              { entity = "light.192_168_1_15"; name = "Entrada"; }
              { entity = "light.192_168_1_54"; name = "Lamp"; }
            ];
          }
          {
            type = "media-control";
            entity = "media_player.living_room";
          }
          # media_player.cuarzo and remote.cuarzo come from the Android TV
          # Remote integration (paired in the UI, see tvHost note above).
          {
            type = "media-control";
            entity = "media_player.cuarzo";
          }
          {
            type = "horizontal-stack";
            cards = [
              {
                type = "button";
                name = "TV On";
                icon = "mdi:television";
                show_state = false;
                tap_action = { action = "perform-action"; perform_action = "media_player.turn_on"; target.entity_id = "media_player.cuarzo"; };
              }
              {
                type = "button";
                name = "TV Off";
                icon = "mdi:power";
                show_state = false;
                tap_action = { action = "perform-action"; perform_action = "media_player.turn_off"; target.entity_id = "media_player.cuarzo"; };
              }
              {
                type = "button";
                name = "Vol -";
                icon = "mdi:volume-minus";
                show_state = false;
                tap_action = { action = "perform-action"; perform_action = "media_player.volume_down"; target.entity_id = "media_player.cuarzo"; };
              }
              {
                type = "button";
                name = "Vol +";
                icon = "mdi:volume-plus";
                show_state = false;
                tap_action = { action = "perform-action"; perform_action = "media_player.volume_up"; target.entity_id = "media_player.cuarzo"; };
              }
              {
                type = "button";
                name = "Home";
                icon = "mdi:home";
                show_state = false;
                tap_action = { action = "perform-action"; perform_action = "remote.send_command"; target.entity_id = "remote.cuarzo"; data.command = "HOME"; };
              }
            ];
          }
          {
            type = "light";
            entity = "light.tv_backlight";
            name = "TV Backlight";
          }
        ];
      }

      {
        title = "Cameras";
        path = "cameras";
        icon = "mdi:cctv";
        cards = [
          {
            type = "picture-entity";
            title = "Reolink E1 (Living Room)";
            entity = "camera.reolink_e1";
            camera_view = "live";
          }
          {
            type = "picture-entity";
            title = "Xiaomi C200";
            entity = "camera.xiaomi_c200";
            camera_view = "live";
          }
        ];
      }

      {
        title = "Lights";
        path = "lights";
        icon = "mdi:lightbulb-group";
        cards = [
          {
            type = "light";
            entity = "light.192_168_1_49";
            name = "Bedroom";
          }
          {
            type = "light";
            entity = "light.192_168_1_14";
            name = "Office";
          }
          {
            type = "light";
            entity = "light.192_168_1_16";
            name = "Kitchen";
          }
          {
            type = "light";
            entity = "light.192_168_1_15";
            name = "Entrada";
          }
          {
            type = "light";
            entity = "light.192_168_1_54";
            name = "Lamp";
          }
        ];
      }

      {
        title = "System";
        path = "system";
        icon = "mdi:server";
        cards = [
          {
            type = "gauge";
            name = "CPU";
            entity = "sensor.system_monitor_processor_use";
            unit = "%";
            severity = { green = 0; yellow = 60; red = 85; };
          }
          {
            type = "gauge";
            name = "Memory";
            entity = "sensor.system_monitor_memory_use";
            unit = "%";
            severity = { green = 0; yellow = 70; red = 90; };
          }
          {
            type = "gauge";
            name = "CPU Temp";
            entity = "sensor.system_monitor_processor_temperature";
            unit = "°C";
            severity = { green = 0; yellow = 70; red = 85; };
          }
          {
            type = "entities";
            title = "Storage & Host";
            entities = [
              { entity = "sensor.system_monitor_disk_use_partition_root"; name = "Disk / (root)"; }
              { entity = "sensor.system_monitor_disk_use_srv_media"; name = "Disk /srv/media"; }
              { entity = "sensor.system_monitor_disk_use_nix_storage"; name = "Disk /nix/storage"; }
              { entity = "sensor.system_monitor_load_1_min"; name = "Load (1m)"; }
              { entity = "sensor.system_monitor_last_boot"; name = "Last boot"; }
              { entity = "sensor.system_monitor_ipv4_address_enp7s0"; name = "IPv4"; }
            ];
          }
        ];
      }

      {
        title = "Dev News";
        path = "dev-news";
        icon = "mdi:rss";
        panel = true;
        cards = [
          {
            type = "iframe";
            title = "Dev News";
            url = "https://rss.minerales.network/";
            aspect_ratio = "100%";
          }
        ];
      }
    ];
  };

  # configDir: entity registry, automations, and the recorder database, i.e.
  # every pairing and all history. Not reproducible from this config.
  backups.restic.sources = [ config.services.home-assistant.configDir ];
}
  ;
}
