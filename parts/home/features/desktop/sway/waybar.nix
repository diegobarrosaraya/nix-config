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

      inherit (config.colorscheme) colors;
      inherit (config.stylix) fonts;

      common = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;
        modules-left = [
          "sway/workspaces"
          "sway/mode"
          "custom/scratchpad"
        ];
        modules-center = [ "sway/window" ];
      };

      baseSize = fonts.sizes.desktop + 4;
      trayIconSize = baseSize;

      u = code: builtins.fromJSON ''"\u${code}"'';

      workspaces = import ./_workspaces.nix {
        inherit lib colors;
        labelFont = fonts.sansSerif.name;
      };

      pipe = "<span foreground='#${colors.base03}'>|</span>";
      iconRam = builtins.fromJSON ''"\udb80\udf5b"'';
      iconCb = u "e8e8";
      iconLock = u "e897";
      iconServer = u "e875";
      iconSync = u "e627";
      iconCloud = u "e2bd";
      iconShare = u "e80d";
      iconCamera = u "e412";
      # State glyphs shared by the cb/tailscale/cobalto/syncthing modules so a
      # down/warning state is readable by shape, not just by waybar's color class.
      iconStateError = u "e5c9";
      iconStateWarning = u "e002";

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

      waybar-mic = pkgs.writeShellScriptBin "waybar-mic" ''
        pactl=${lib.getExe' pkgs.pulseaudio "pactl"}
        # Streams that read an output monitor (cava, desktop-sound recorders) are not the mic.
        monitors=$($pactl list short sources 2>/dev/null | awk '$2 ~ /\.monitor$/ {print $1}')
        count=$($pactl list short source-outputs 2>/dev/null \
          | awk -v m="$monitors" 'BEGIN { n = split(m, a, "\n"); for (i = 1; i <= n; i++) mon[a[i]] = 1 } !($2 in mon)' \
          | wc -l)
        if [ "$count" -gt 0 ]; then
          ${lib.getExe pkgs.jq} -cn --arg t "${pipe} [ ${u "f130"}  mic ]" '{text: $t, class: "critical", tooltip: "Microphone in use"}'
        else
          printf '{"text":""}\n'
        fi
      '';

      waybar-jack = pkgs.writeShellScriptBin "waybar-jack" ''
        if systemctl --user is-active --quiet pipewire; then
          printf '{"text":"%s","class":"ok","tooltip":"JACK (pipewire-jack) running"}\n' "${u "efe6"}"
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

      # Audio-only meeting recorder: click once to name it and start, click again to stop.
      # Records the default output monitor (them) and the default mic (me), mixed to one mono
      # Opus track. The mic is level-normalised because Meet and other call apps leave it quiet.
      meetingDir = "${config.xdg.userDirs.documents}/Meetings";

      waybar-meeting-rec = pkgs.writeShellScriptBin "waybar-meeting-rec" ''
        state="''${XDG_RUNTIME_DIR:-/tmp}/meeting-rec"
        refresh() { pkill -RTMIN+8 waybar || true; }

        if [ -f "$state" ] && kill -0 "$(head -n1 "$state")" 2>/dev/null; then
          pid=$(head -n1 "$state")
          file=$(tail -n1 "$state")
          kill -INT "$pid"
          # SIGINT lets ffmpeg close the Ogg file; wait so the icon flips only when it is done.
          while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
          rm -f "$state"
          refresh
          ${lib.getExe pkgs.libnotify} "Recording saved" "$file"
          exit 0
        fi

        name=$(echo | ${config.launcher.dmenu} --require-match false --prompt-text "meeting name:")
        [ -z "$name" ] && exit 0
        slug=$(printf '%s' "$name" | tr -cs '[:alnum:]' '-' | sed 's/^-//; s/-$//')
        [ -n "$slug" ] || slug=meeting

        mkdir -p "${meetingDir}"
        file="${meetingDir}/$(date +%F_%H%M)_$slug.ogg"

        setsid ${lib.getExe pkgs.ffmpeg} -nostdin -loglevel error \
          -f pulse -i @DEFAULT_MONITOR@ -f pulse -i @DEFAULT_SOURCE@ \
          -filter_complex '[0]aformat=channel_layouts=mono[them];[1]aformat=channel_layouts=mono,highpass=f=100,dynaudnorm=f=150:g=15:m=12[me];[them][me]amix=inputs=2:normalize=0,alimiter=limit=0.9:level=0,aformat=channel_layouts=mono' \
          -c:a libopus -b:a 32k -application voip "$file" &
        printf '%s\n%s\n' "$!" "$file" > "$state"
        refresh
      '';

      waybar-meeting-rec-status = pkgs.writeShellScriptBin "waybar-meeting-rec-status" ''
        state="''${XDG_RUNTIME_DIR:-/tmp}/meeting-rec"
        if [ -f "$state" ] && kill -0 "$(head -n1 "$state")" 2>/dev/null; then
          ${lib.getExe pkgs.jq} -cn --arg t "${u "e061"}" --arg f "$(tail -n1 "$state")" \
            '{text: $t, class: "recording", tooltip: "Recording: \($f)\nClick to stop"}'
        else
          printf '{"text":"%s","class":"idle","tooltip":"Record a meeting"}\n' "${u "e029"}"
        fi
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
          printf '{"text":"%s %s","class":"has-items","tooltip":"%s window(s) in scratchpad"}\n' "${u "e53b"}" "$COUNT" "$COUNT"
        else
          printf '{"text":"%s","class":"empty","tooltip":"Scratchpad empty"}\n' "${u "e53b"}"
        fi
      '';

      locationClockModule = {
        exec = "${lib.getExe waybar-location-clock}";
        interval = 1;
        return-type = "json";
      };

      networkModule = {
        format-wifi = "${pipe} ${u "f1eb"}  {essid}";
        format-ethernet = "${pipe} ${u "f1eb"}  {ifname}";
        format-disconnected = "${pipe} [ ${u "f127"}  down ]";
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

        "sway/window" = {
          format = "{title}";
          max-length = 70;
        };

        clock = {
          format = "${u "f017"}  {:%a %d %b  %H:%M}";
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

        "custom/sep" = {
          exec = "echo x";
          interval = "once";
          format = pipe;
          tooltip = false;
        };

        "custom/sep#clocks" = {
          exec = "echo x";
          interval = "once";
          format = pipe;
          tooltip = false;
        };

        "custom/mic" = {
          exec = "${lib.getExe waybar-mic}";
          interval = 2;
          return-type = "json";
        };

        "custom/meeting-rec" = {
          exec = "${lib.getExe waybar-meeting-rec-status}";
          interval = 30;
          signal = 8;
          return-type = "json";
          on-click = "${lib.getExe waybar-meeting-rec}";
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
          format = "${pipe} ${u "f001"}  {dynamic}";
          format-paused = "${pipe} ${u "f001"}  {dynamic}";
          dynamic-len = 28;
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "${u "e8f4"}";
            deactivated = "${u "e8f5"}";
          };
        };

        "power-profiles-daemon" = {
          format = "{icon}";
          tooltip-format = "Power profile: {profile}";
          format-icons = {
            default = "${u "e8ac"}";
            performance = "${u "ea0b"}";
            balanced = "${u "eaf6"}";
            power-saver = "${u "ea35"}";
          };
        };

        temperature = {
          critical-threshold = 80;
          format = "${u "f076"} {temperatureC}°C";
          tooltip = true;
        };

        disk = {
          path = "/nix";
          states = {
            warning = 85;
            critical = 95;
          };
          format = "";
          format-warning = "${pipe} [ ${u "f0a0"}  {path} {percentage_used}% ]";
          format-critical = "${pipe} [ ${u "f0a0"}  {path} {percentage_used}% ]";
          tooltip-format = "{used} used / {total} ({percentage_used}%)";
          interval = 30;
        };

        privacy = {
          icon-spacing = 4;
          icon-size = 18;
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
          format = "${pipe} ${u "f028"}  {volume}%";
          format-muted = "${pipe} [ ${u "f026"}  muted ]";
          format-bluetooth = "${pipe} ${u "f025"}  {volume}%";
          on-click = "alacritty -e wiremix";
        };

        wireplumber = {
          format = "${u "e050"}";
          format-muted = "${u "e04f"}";
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
          states = {
            warning = 70;
            critical = 95;
          };
          format = "${pipe} ${u "f2db"}  {usage}%";
          format-warning = "${pipe} [ ${u "f2db"}  {usage}% ]";
          format-critical = "${pipe} [ ${u "f2db"}  {usage}% ]";
          format-alt = "${pipe} ${u "f2db"}  {avg_frequency} GHz";
          tooltip = true;
          interval = 5;
          on-click = "alacritty -e ${pkgs.bottom}/bin/btm";
        };

        memory = {
          states = {
            warning = 75;
            critical = 90;
          };
          format = "${pipe} ${iconRam}  {used:0.1f}G";
          format-warning = "${pipe} [ ${iconRam}  {used:0.1f}G ]";
          format-critical = "${pipe} [ ${iconRam}  {used:0.1f}G ]";
          format-alt = "${pipe} ${iconRam}  {used:0.1f}GiB/{total:0.1f}GiB";
          tooltip-format = "{used:0.1f}G / {total:0.1f}G";
          interval = 5;
          on-click = "alacritty -e ${pkgs.bottom}/bin/btm";
        };

        backlight = {
          format = "{icon} {percent}%";
          format-icons = [ "${u "e430"}" ];
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "${pipe} {icon}  {capacity}%";
          format-warning = "${pipe} [ {icon}  {capacity}% ]";
          format-critical = "${pipe} [ {icon}  {capacity}% ]";
          format-charging = "${pipe} ${u "f0e7"}  {capacity}%";
          format-plugged = "${pipe} ${u "f1e6"}  {capacity}%";
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
          format = "${pipe} ${u "e1a7"}";
          format-on = "${pipe} ${u "e1a7"}";
          format-off = "";
          format-disabled = "";
          format-connected = "${pipe} ${u "e1a7"}";
          format-connected-battery = "${pipe} ${u "e1a7"} {device_battery_percentage}%";
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
          # External screens (anything but the laptop panel): the full bar.
          (
            common
            // {
              output = "!${laptop}";
              modules-right = [
                "custom/meeting-rec"
                "custom/mic"
                "mpris"
                "custom/sep"
                "group/services"
                "disk"
                "cpu"
                "memory"
                "network"
                "bluetooth"
                "pulseaudio"
                "battery"
                "custom/sep#clocks"
                "group/worldclocks"
              ];
            }
            // sharedModules
          )
          # Laptop panel: no music and no services drawer.
          (
            common
            // {
              output = laptop;
              modules-right = [
                "custom/meeting-rec"
                "custom/mic"
                "disk"
                "cpu"
                "memory"
                "network"
                "pulseaudio"
                "battery"
                "custom/sep#clocks"
                "group/worldclocks"
              ];
            }
            // sharedModules
          )
        ];

        style = ''

          * {
            font-family: "${fonts.monospace.name}", "Material Symbols Filled";
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

          /* Bracket style: "[name]" text in the mono font. Focused is bold accent, the rest dim. */
          window#waybar #workspaces button {
            font-family: "${fonts.monospace.name}";
            font-weight: normal;
            padding: 0 2px;
            background-image: none;
            background-color: transparent;
            border: none;
            border-radius: 0;
            box-shadow: none;
            outline: none;
            text-shadow: none;
            border-image: none;
            color: #${colors.base00};
            -gtk-icon-effect: none;
          }

          window#waybar #workspaces button * {
            text-shadow: none;
            font-family: "${fonts.monospace.name}";
            font-weight: inherit;
          }

          window#waybar #workspaces button:hover {
            background-color: transparent;
            background-image: none;
            box-shadow: none;
          }

          window#waybar #workspaces button.focused,
          window#waybar #workspaces button.focused * {
            color: #${colors.base0C};
            font-weight: bold;
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

          #battery.warning:not(.charging),
          #cpu.warning,
          #memory.warning,
          #disk.warning {
            color: #${colors.base09};
          }

          #battery.critical:not(.charging),
          #cpu.critical,
          #memory.critical,
          #disk.critical,
          #network.disconnected,
          #pulseaudio.muted {
            color: #${colors.base08};
          }

          #battery.charging {
            color: #${colors.base0B};
          }

          #cpu {
            color: #${colors.base07};
          }

          #memory {
            color: #${colors.base07};
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
          #custom-meeting-rec,
          #custom-scratchpad {
            padding: 0 12px;
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
          #custom-meeting-rec,
          #custom-scratchpad,
          #idle_inhibitor,
          #power-profiles-daemon {
            font-family: "Material Symbols Filled";
          }

          #custom-meeting-rec.idle {
            color: #${colors.base03};
          }

          #custom-meeting-rec.recording {
            color: #${colors.base08};
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
          #custom-mic,
          #custom-sep,
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

          #custom-mic.critical {
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
        waybar-mic
        waybar-syncthing
        waybar-jocalsend-icon
        waybar-jocalsend
        waybar-droidcam-icon
        waybar-droidcam
        waybar-meeting-rec
        waybar-meeting-rec-status
        waybar-location-clock
        waybar-scratchpad
      ];

      systemd.user.services.waybar.Service.LimitNOFILE = 1048576;
    };
}
