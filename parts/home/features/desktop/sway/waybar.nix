{ ... }:
{
  # Restored from the pre-mango stash: one bar with groups (worldclocks, services,
  # hardware, audio). Replaces swaybar.
  flake.modules.homeManager.desktop-sway-waybar =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Outputs matched by "make model serial": connector names (DP-8, DP-9, ...)
      # change between docks. Waybar has no partial match.
      laptop = "Lenovo Group Limited 0x403C";
      samsung = "Samsung Electric Company LS27A600U HCJW500005";

      inherit (config.colorscheme) colors;
      inherit (config.stylix) fonts;

      baseSize = fonts.sizes.desktop;
      trayIconSize = baseSize;

      u = code: builtins.fromJSON ''"\u${code}"'';

      workspaces = import ./_workspaces.nix {
        inherit lib;
        labelFont = fonts.sansSerif.name;
      };

      iconCb = u "f3ed";
      iconLock = u "f023";
      iconServer = u "f233";
      iconSync = u "f021";
      iconCloud = u "f0c2";
      iconShare = u "f1e0";
      iconCamera = u "f030";
      # State glyphs shared by the cb/tailscale/cobalto/syncthing modules so a
      # down/warning state is readable by shape, not just by waybar's color class.
      iconStateError = u "f057";
      iconStateWarning = u "f071";

      waybar-cb = pkgs.writeShellScriptBin "waybar-cb" ''
        if systemctl is-active --quiet cbagentd; then
          printf '{"text":"%s","class":"ok","tooltip":"CB agent running"}\n' "${iconCb}"
        else
          printf '{"text":"%s","class":"error","tooltip":"CB agent not running"}\n' "${iconStateError}"
        fi
      '';

      waybar-tailscale = pkgs.writeShellScriptBin "waybar-tailscale" ''
        DATA=$(${lib.getExe pkgs.tailscale} status --json 2>/dev/null) || DATA=""

        if [ -z "$DATA" ]; then
          printf '{"text":"%s","class":"error","tooltip":"tailscale unavailable"}\n' "${iconStateError}"
          exit 0
        fi

        STATE=$(printf '%s' "$DATA" | ${lib.getExe pkgs.jq} -r '.BackendState // "unknown"')
        PEERS=$(printf '%s' "$DATA" | ${lib.getExe pkgs.jq} '[.Peer // {} | to_entries[] | select(.value.Online == true)] | length')

        case "$STATE" in
          Running)
            printf '{"text":"%s","class":"ok","tooltip":"Tailscale up — %s peer(s) online"}\n' "${iconLock}" "$PEERS"
            ;;
          Stopped)
            printf '{"text":"%s","class":"off","tooltip":"Tailscale stopped"}\n' "${iconStateError}"
            ;;
          NeedsLogin|NoState)
            printf '{"text":"%s","class":"warning","tooltip":"Tailscale: %s"}\n' "${iconStateWarning}" "$STATE"
            ;;
          *)
            printf '{"text":"%s","class":"warning","tooltip":"Tailscale: %s"}\n' "${iconStateWarning}" "$STATE"
            ;;
        esac
      '';

      waybar-warp = pkgs.writeShellScriptBin "waybar-warp" ''
        OUT=$(${lib.getExe' pkgs.cloudflare-warp "warp-cli"} status 2>&1) || OUT=""

        case "$OUT" in
          *Connected*)
            printf '{"text":"%s","class":"ok","tooltip":"WARP connected"}\n' "${iconCloud}"
            ;;
          *Disconnected*)
            printf '{"text":"%s","class":"off","tooltip":"WARP disconnected"}\n' "${iconStateError}"
            ;;
          *Registration*Missing*)
            printf '{"text":"%s","class":"warning","tooltip":"WARP not enrolled"}\n' "${iconStateWarning}"
            ;;
          *)
            printf '{"text":"%s","class":"error","tooltip":"WARP unavailable"}\n' "${iconStateError}"
            ;;
        esac
      '';

      waybar-cobalto = pkgs.writeShellScriptBin "waybar-cobalto" ''
        RESULT=$(ping -c 1 -W 2 cobalto 2>&1)
        if echo "$RESULT" | grep -q 'time='; then
          LATENCY=$(echo "$RESULT" | grep -oP 'time=\K[0-9.]+')
          printf '{"text":"%s","class":"ok","tooltip":"cobalto: %s ms"}\n' "${iconServer}" "$LATENCY"
        else
          printf '{"text":"%s","class":"error","tooltip":"cobalto unreachable"}\n' "${iconStateError}"
        fi
      '';

      waybar-jack = pkgs.writeShellScriptBin "waybar-jack" ''
        if systemctl --user is-active --quiet pipewire; then
          printf '{"text":"%s","class":"ok","tooltip":"JACK (pipewire-jack) running"}\n' "${u "f8d9"}"
        else
          printf '{"text":"%s","class":"error","tooltip":"JACK (pipewire) not running"}\n' "${iconStateError}"
        fi
      '';

      waybar-syncthing = pkgs.writeShellScriptBin "waybar-syncthing" ''
        CONFIG_XML="${config.xdg.configHome}/syncthing/config.xml"
        FALLBACK_XML="$HOME/.local/state/syncthing/config.xml"

        if [ -f "$CONFIG_XML" ]; then
          APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' "$CONFIG_XML" | head -1)
        elif [ -f "$FALLBACK_XML" ]; then
          APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' "$FALLBACK_XML" | head -1)
        fi

        if [ -z "''${APIKEY:-}" ]; then
          printf '{"text":"%s","class":"error","tooltip":"Syncthing: API key not found"}\n' "${iconStateError}"
          exit 0
        fi

        DATA=$(${lib.getExe pkgs.curl} -sf -H "X-API-Key: $APIKEY" http://127.0.0.1:8384/rest/system/connections 2>/dev/null) || DATA=""

        if [ -z "$DATA" ]; then
          printf '{"text":"%s","class":"error","tooltip":"Syncthing: not reachable"}\n' "${iconStateError}"
          exit 0
        fi

        CONNECTED=$(printf '%s' "$DATA" | ${lib.getExe pkgs.jq} '[.connections // {} | to_entries[] | select(.value.connected == true)] | length')
        printf '{"text":"%s","class":"ok","tooltip":"Syncthing: %s device(s) connected"}\n' "${iconSync}" "$CONNECTED"
      '';

      waybar-jocalsend-icon = pkgs.writeShellScriptBin "waybar-jocalsend-icon" ''
        printf '{"text":"%s","tooltip":"jocalsend"}\n' "${iconShare}"
      '';

      waybar-jocalsend = pkgs.writeShellScriptBin "waybar-jocalsend" ''
        CHOICE=$(printf 'Send file\nReceive\nOpen TUI' | ${config.launcher.dmenu} --prompt-text "jocalsend")
        [ -z "$CHOICE" ] && exit 0
        case "$CHOICE" in
          "Send file")
            PATH_TO_SEND=$(echo | ${config.launcher.dmenu} --require-match false --prompt-text "file path:")
            [ -z "$PATH_TO_SEND" ] && exit 0
            alacritty -e ${lib.getExe pkgs.jocalsend} send "$PATH_TO_SEND"
            ;;
          "Receive")
            alacritty -e ${lib.getExe pkgs.jocalsend} receive
            ;;
          "Open TUI")
            alacritty -e ${lib.getExe pkgs.jocalsend}
            ;;
        esac
      '';

      waybar-droidcam-icon = pkgs.writeShellScriptBin "waybar-droidcam-icon" ''
        printf '{"text":"%s","tooltip":"droidcam"}\n' "${iconCamera}"
      '';

      waybar-droidcam = pkgs.writeShellScriptBin "waybar-droidcam" ''
        CHOICE=$(printf 'Connect via IP\nConnect via ADB (USB)\nConnect via iOS (usbmuxd)' | ${config.launcher.dmenu} --prompt-text "droidcam")
        [ -z "$CHOICE" ] && exit 0
        case "$CHOICE" in
          "Connect via IP")
            IP=$(echo | ${config.launcher.dmenu} --require-match false --prompt-text "phone ip:")
            [ -z "$IP" ] && exit 0
            alacritty -e droidcam-cli -a -v "$IP" 4747
            ;;
          "Connect via ADB (USB)")
            alacritty -e droidcam-cli -a -v adb 4747
            ;;
          "Connect via iOS (usbmuxd)")
            alacritty -e droidcam-cli -a -v ios 4747
            ;;
        esac
      '';

      waybar-location-clock = pkgs.writeShellScriptBin "waybar-location-clock" ''
        set -eu

        tz=$(readlink /etc/localtime 2>/dev/null || true)
        case "$tz" in
          *share/zoneinfo/*)
            tz=''${tz##*share/zoneinfo/}
            ;;
          *)
            tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)
            ;;
        esac
        [ -n "$tz" ] || tz="UTC"

        case "$tz" in
          America/Santiago)    city="Santiago" ;;
          America/Los_Angeles) city="Palo Alto" ;;
          Europe/London)       city="London" ;;
          Europe/Paris)        city="Paris" ;;
          Australia/Sydney)    city="Sydney" ;;
          *) city=$(printf '%s' "$tz" | sed 's|.*/||; s|_| |g') ;;
        esac

        time=$(date '+%a %b %d  %H:%M')

        if [ "$tz" = "America/Santiago" ]; then
          class="home"
        else
          class="away"
        fi

        now="$city  ($tz)"
        calendar=$(cal)

        ${lib.getExe pkgs.jq} -cn \
          --arg text "$time" \
          --arg class "$class" \
          --arg now "$now" \
          --arg calendar "$calendar" \
          '{text: $text, class: $class, tooltip: "<tt><small>\($calendar)</small></tt>\n<small>\($now)</small>"}'
      '';

      waybar-scratchpad = pkgs.writeShellScriptBin "waybar-scratchpad" ''
        set -eu

        COUNT=$(${lib.getExe pkgs.jq} '[.. | objects | select(.type == "con" and .scratchpad_state? and .scratchpad_state != "none")] | length' < <(swaymsg -t get_tree))

        if [ "$COUNT" -gt 0 ]; then
          printf '{"text":"%s %s","class":"has-items","tooltip":"%s window(s) in scratchpad"}\n' "${u "f2d2"}" "$COUNT" "$COUNT"
        else
          printf '{"text":"%s","class":"empty","tooltip":"Scratchpad empty"}\n' "${u "f2d2"}"
        fi
      '';

      locationClockModule = {
        exec = "${lib.getExe waybar-location-clock}";
        interval = 1;
        return-type = "json";
      };

      networkModule = {
        format-wifi = "${u "f1eb"}";
        format-ethernet = "${u "f796"}";
        format-disconnected = "${u "f071"} Disconnected";
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
        tooltip-format-ethernet = "{ifname}";
        on-click = "alacritty -e wifitui";
      };

      # Module defs shared by the top and bottom bars on eDP-1.
      sharedModules = {
        "sway/workspaces" = workspaces.waybarWorkspaces;

        "sway/mode" = {
          format = "<span style=\"italic\">{}</span>";
        };

        "custom/scratchpad" = {
          exec = "${lib.getExe waybar-scratchpad}";
          interval = 5;
          return-type = "json";
          on-click = "swaymsg scratchpad show";
        };

        tray = {
          icon-size = trayIconSize;
          spacing = 10;
        };

        "custom/location-clock" = locationClockModule;

        clock = {
          format = "{:%a %b %d  %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };

        "clock#palo-alto" = {
          timezone = "America/Los_Angeles";
          format = "Palo Alto  {:%H:%M}";
          tooltip-format = "{:%A, %b %d}";
        };

        "clock#london" = {
          timezone = "Europe/London";
          format = "London  {:%H:%M}";
          tooltip-format = "{:%A, %b %d}";
        };

        "clock#paris" = {
          timezone = "Europe/Paris";
          format = "Paris  {:%H:%M}";
          tooltip-format = "{:%A, %b %d}";
        };

        "clock#australia" = {
          timezone = "Australia/Sydney";
          format = "Sydney  {:%H:%M}";
          tooltip-format = "{:%A, %b %d}";
        };

        "clock#santiago" = {
          timezone = "America/Santiago";
          format = "Santiago  {:%H:%M}";
          tooltip-format = "{:%A, %b %d}";
        };

        "clock#utc" = {
          timezone = "UTC";
          format = "UTC  {:%H:%M}";
          tooltip-format = "{:%A, %b %d}";
        };

        "group/worldclocks" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 300;
            children-class = "drawer-child";
            transition-left-to-right = true;
            click-to-reveal = false;
          };
          modules = [
            "clock"
            "clock#palo-alto"
            "clock#london"
            "clock#paris"
            "clock#australia"
            "clock#santiago"
            "clock#utc"
          ];
        };

        "custom/cb" = {
          exec = "${lib.getExe waybar-cb}";
          interval = 30;
          return-type = "json";
        };

        "custom/tailscale" = {
          exec = "${lib.getExe waybar-tailscale}";
          interval = 15;
          return-type = "json";
        };

        "custom/warp" = {
          exec = "${lib.getExe waybar-warp}";
          interval = 15;
          return-type = "json";
          on-click = "sh -c '${lib.getExe' pkgs.cloudflare-warp "warp-cli"} status | grep -q Disconnected && ${lib.getExe' pkgs.cloudflare-warp "warp-cli"} connect || ${lib.getExe' pkgs.cloudflare-warp "warp-cli"} disconnect'";
          on-click-right = "alacritty --hold -e ${lib.getExe' pkgs.cloudflare-warp "warp-cli"} status";
        };

        "custom/cobalto" = {
          exec = "${lib.getExe waybar-cobalto}";
          interval = 60;
          return-type = "json";
        };

        "custom/jack" = {
          exec = "${lib.getExe waybar-jack}";
          interval = 30;
          return-type = "json";
        };

        "custom/syncthing" = {
          exec = "${lib.getExe waybar-syncthing}";
          interval = 30;
          return-type = "json";
          on-click = "xdg-open http://127.0.0.1:8384";
        };

        "custom/jocalsend-icon" = {
          exec = "${lib.getExe waybar-jocalsend-icon}";
          interval = "once";
          return-type = "json";
          on-click = "${lib.getExe waybar-jocalsend}";
        };

        "custom/droidcam-icon" = {
          exec = "${lib.getExe waybar-droidcam-icon}";
          interval = "once";
          return-type = "json";
          on-click = "${lib.getExe waybar-droidcam}";
        };

        mpris = {
          format = "{player_icon} {dynamic}";
          format-paused = "{status_icon} {dynamic}";
          player-icons = {
            default = "${u "f001"}";
          };
          status-icons = {
            paused = "${u "f04c"}";
          };
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "${u "f06e"}";
            deactivated = "${u "f070"}";
          };
        };

        "power-profiles-daemon" = {
          format = "{icon}";
          tooltip-format = "Power profile: {profile}";
          format-icons = {
            default = "${u "f011"}";
            performance = "${u "f0e7"}";
            balanced = "${u "f24e"}";
            power-saver = "${u "f2ca"}";
          };
        };

        temperature = {
          critical-threshold = 80;
          format = "${u "f2c9"} {temperatureC}°C";
          tooltip = true;
        };

        disk = {
          path = "/";
          format = "${u "f0a0"} {percentage_used}%";
          tooltip-format = "{used} used / {total} ({percentage_used}%)";
          interval = 30;
        };

        privacy = {
          icon-spacing = 4;
          icon-size = 14;
          transition-duration = 250;
        };

        "group/hardware" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 300;
            children-class = "drawer-child";
            transition-left-to-right = false;
            click-to-reveal = false;
          };
          modules = [
            "battery"
            "battery#percentage"
            "power-profiles-daemon"
            "temperature"
            "disk"
            "cpu"
            "memory"
          ];
        };

        "group/audio" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 300;
            children-class = "drawer-child";
            transition-left-to-right = false;
            click-to-reveal = false;
          };
          modules = [
            "pulseaudio"
            "custom/jack"
            "mpris"
            "wireplumber"
          ];
        };

        pulseaudio = {
          format = "${u "f028"}";
          format-muted = "${u "f6a9"}";
          format-bluetooth = "${u "f294"}";
          on-click = "alacritty -e wiremix";
        };

        wireplumber = {
          format = "${u "f028"}";
          format-muted = "${u "f6a9"}";
        };

        "group/services" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 300;
            children-class = "drawer-child";
            transition-left-to-right = false;
            click-to-reveal = false;
          };
          modules = [
            "custom/cb"
            "custom/tailscale"
            "custom/warp"
            "idle_inhibitor"
            "custom/cobalto"
            "custom/syncthing"
            "custom/jocalsend-icon"
            "custom/droidcam-icon"
            "tray"
          ];
        };

        cpu = {
          format = "${u "f2db"} {usage}%";
          format-alt = "${u "f2db"} {avg_frequency} GHz";
          tooltip = true;
          interval = 5;
          on-click = "alacritty -e ${pkgs.bottom}/bin/btm";
        };

        memory = {
          format = "${u "f538"} {}%";
          format-alt = "${u "f538"} {used:0.1f}GiB/{total:0.1f}GiB";
          tooltip-format = "{used:0.1f}G / {total:0.1f}G";
          interval = 5;
          on-click = "alacritty -e ${pkgs.bottom}/bin/btm";
        };

        backlight = {
          format = "{icon} {percent}%";
          format-icons = [ "${u "f185"}" ];
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon}";
          format-charging = "${u "e55b"}";
          format-plugged = "${u "f1e6"}";
          format-icons = [
            "${u "f244"}"
            "${u "f243"}"
            "${u "f242"}"
            "${u "f241"}"
            "${u "f240"}"
          ];
        };

        "battery#percentage" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}%";
        };

        network = networkModule;

        bluetooth = {
          format = "${u "f294"}";
          format-on = "${u "f294"}";
          format-off = "";
          format-disabled = "";
          format-connected = "${u "f294"}";
          format-connected-battery = "${u "f294"} {device_battery_percentage}%";
          format-no-controller = "";
          tooltip-format = "{controller_alias}\t{controller_address}\n\n{status}";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
          on-click = "alacritty -e bluetuith";
        };
      };
    in
    {
      # swaybar is replaced by waybar.
      wayland.windowManager.sway.config.bars = lib.mkForce [ ];

      programs.waybar = {
        enable = true;

        systemd = {
          enable = true;
          targets = [ "sway-session.target" ];
        };

        settings = [
          (
            {
              layer = "top";
              position = "top";
              height = 36;
              spacing = 4;
              output = [
                laptop
                samsung
              ];
              modules-left = [
                "sway/workspaces"
                "sway/mode"
                "custom/scratchpad"
              ];
              modules-center = [
              ];
              modules-right = [
                "privacy"
                "sway/language"
                "group/services"
                "group/hardware"
                "group/audio"
                "bluetooth"
                "network"
                "group/worldclocks"
              ];
            }
            // sharedModules
          )
        ];

        style = ''

          * {
            font-family: "${fonts.sansSerif.name}", "Workspace Icons", "Font Awesome 7 Brands", "Font Awesome 7 Free Solid";
            font-size: ${toString baseSize}px;
            border: none;
            border-radius: 0;
          }

          window#waybar {
            background-color: #${colors.base00};
            color: #${colors.base07};
            border: none;
            border-radius: 0;
          }

          window#waybar.hidden {
            opacity: 1;
          }

          window#waybar #workspaces button {
            font-family: "Workspace Icons", "Font Awesome 7 Brands", "Font Awesome 7 Free Solid";
            font-weight: normal;
            padding: 0 8px;
            background-image: none;
            border: none;
            border-radius: 0;
            box-shadow: none;
            outline: none;
            text-shadow: none;
            border-image: none;
            color: #${colors.base07};
            -gtk-icon-effect: none;
          }

          window#waybar #workspaces button * {
            text-shadow: none;
            font-family: "Workspace Icons", "Font Awesome 7 Brands", "Font Awesome 7 Free Solid";
            font-weight: normal;
          }

          window#waybar #workspaces button label {
            font-family: "Workspace Icons", "Font Awesome 7 Brands", "Font Awesome 7 Free Solid", "${fonts.sansSerif.name}";
          }

          window#waybar #workspaces button.urgent:not(.focused),
          window#waybar #workspaces button.active.urgent:not(.focused) {
            background-color: #${colors.base08};
            color: #${colors.base00};
            box-shadow: none;
          }

          window#waybar #workspaces button.urgent:not(.focused) *,
          window#waybar #workspaces button.active.urgent:not(.focused) * {
            color: #${colors.base00};
          }

          window#waybar #workspaces button:hover {
            background-color: #${colors.base01};
            background-image: none;
            color: #${colors.base07};
            box-shadow: none;
          }

          window#waybar #workspaces button.focused,
          window#waybar #workspaces button.focused *,
          window#waybar #workspaces button.focused label,
          window#waybar #workspaces button.active,
          window#waybar #workspaces button.active * {
            color: #${colors.base0D};
            font-weight: 400;
          }

          window#waybar #workspaces button.focused,
          window#waybar #workspaces button.active {
            background-image: none;
            box-shadow: none;
            border-radius: 0px;
          }

          #mode {
            background-color: #${colors.base0E};
            color: #${colors.base00};
            padding: 0 10px;
          }

          #window {
            color: #${colors.base04};
            padding: 0 10px;
          }

          #battery,
          #cpu,
          #memory,
          #backlight,
          #network,
          #pulseaudio,
          #bluetooth,
          #language {
            padding: 0 12px;
            color: #${colors.base07};
          }

          #custom-location-clock,
          #clock {
            padding: 0 12px;
            color: #${colors.base07};
            font-weight: 500;
          }

          #custom-location-clock.away {
            color: #${colors.base07};
          }

          #battery.warning:not(.charging) {
            color: #${colors.base09};
          }

          #battery.critical:not(.charging) {
            background-color: #${colors.base0F};
            color: #${colors.base00};
            animation: blink 0.5s linear infinite alternate;
          }

          @keyframes blink {
            to {
              background-color: #${colors.base00};
              color: #${colors.base0F};
            }
          }

          #cpu {
            color: #${colors.base07};
          }

          #memory {
            color: #${colors.base07};
          }

          #backlight {
            color: #${colors.base0A};
          }

          #network.disconnected {
            color: #${colors.base0F};
          }

          #pulseaudio.muted {
            color: #${colors.base03};
          }

          #bluetooth.connected {
            color: #${colors.base0D};
          }

          #bluetooth.discovering,
          #bluetooth.discoverable,
          #bluetooth.pairable {
            color: #${colors.base0A};
          }

          #bluetooth.off,
          #bluetooth.disabled {
            color: #${colors.base03};
          }

          #tray > .passive {
            -gtk-icon-effect: dim;
          }

          #tray {
            padding: 0 12px;
            background: #${colors.base0D};
          }

          #tray > .needs-attention {
            -gtk-icon-effect: highlight;
            background-color: #${colors.base0F};
          }

          tooltip {
            background-color: #${colors.base00};
            border: 1px solid #${colors.base0D};
            border-radius: 4px;
          }

          tooltip label {
            color: #${colors.base07};
          }

          #custom-cb,
          #custom-tailscale,
          #custom-warp,
          #custom-cobalto,
          #custom-jack,
          #custom-syncthing,
          #custom-jocalsend-icon,
          #custom-droidcam-icon,
          #custom-scratchpad {
            padding: 0 12px;
            color: #${colors.base07};
          }

          #custom-scratchpad.empty {
            color: #${colors.base03};
          }

          #custom-scratchpad.has-items {
            color: #${colors.base0D};
          }

          #custom-cb.ok,
          #custom-tailscale.ok,
          #custom-warp.ok,
          #custom-cobalto.ok,
          #custom-jack.ok,
          #custom-syncthing.ok {
            color: #${colors.base07};
          }

          #custom-cb.error,
          #custom-tailscale.error,
          #custom-warp.error,
          #custom-cobalto.error,
          #custom-jack.error,
          #custom-syncthing.error {
            color: #${colors.base08};
          }

          #custom-tailscale.warning,
          #custom-warp.warning,
          #custom-syncthing.warning {
            color: #${colors.base09};
          }

          #custom-tailscale.off,
          #custom-warp.off,
          #custom-syncthing.off {
            color: #${colors.base03};
          }

          #custom-syncthing.syncing {
            color: #${colors.base0D};
          }

          #mpris,
          #idle_inhibitor,
          #power-profiles-daemon,
          #temperature,
          #disk,
          #privacy {
            padding: 0 12px;
            color: #${colors.base07};
          }

          #mpris.playing {
            color: #${colors.base0D};
          }

          #mpris.paused {
            color: #${colors.base03};
          }

          #idle_inhibitor.activated {
            color: #${colors.base0A};
          }

          #power-profiles-daemon.performance {
            color: #${colors.base0D};
          }

          #power-profiles-daemon.power-saver {
            color: #${colors.base0C};
          }

          #temperature.critical {
            color: #${colors.base08};
          }

          .privacy-item {
            color: #${colors.base08};
          }

          #group-hardware,
          #group-audio,
          #group-services,
          #group-worldclocks {
            padding: 0;
          }

          .drawer-child {
            padding: 0 12px;
          }
        '';
      };

      home.packages = [
        pkgs.jocalsend
        waybar-cb
        waybar-tailscale
        waybar-warp
        waybar-cobalto
        waybar-jack
        waybar-syncthing
        waybar-jocalsend-icon
        waybar-jocalsend
        waybar-droidcam-icon
        waybar-droidcam
        waybar-location-clock
        waybar-scratchpad
      ];

      systemd.user.services.waybar.Service.LimitNOFILE = 1048576;
    };
}
