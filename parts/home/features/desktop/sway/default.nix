{ config, ... }@top:
{
  flake.modules.homeManager.desktop-sway =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.colorscheme) colors;
      inherit (config) fontProfiles;
      cursorName = config.stylix.cursor.name;
      cursorSize = toString config.stylix.cursor.size;
      # Fixed named workspaces on 1 to 4 (Web, Files, Agents, Notes). The rest are plain numbers.
      workspaces = {
        "1" = {
          name = "Web";
          app = "zen-beta";
          key = "f";
          launch = "zen-beta";
        };
        "2" = {
          name = "Files";
          app = "files";
          key = "e";
          launch = "alacritty --class files -e superfile";
        };
        "3" = {
          name = "Agents";
          app = "zellij-agents";
          key = "a";
          launch = "alacritty --class zellij-agents -e zellij attach --create agents";
        };
        "4" = {
          name = "Notes";
          app = "ZenNotes";
          key = "n";
          launch = "zennotes-desktop";
        };
      };

      launch-or-focus = pkgs.writeShellScriptBin "launch-or-focus" ''
        #!/usr/bin/env bash

        APP_ID="$1"
        WORKSPACE="$2"
        shift 2
        LAUNCH_CMD="$@"

        # APP_ID is a regex, same as sway criteria, so one entry can match several app_ids.
        WINDOW_EXISTS=$(swaymsg -t get_tree | jq -r --arg id "$APP_ID" '.. | objects | select(((.app_id // "") | test("^(" + $id + ")$")) or ((.window_properties.class // "") | test("^(" + $id + ")$"))) | .id' 2>/dev/null | head -1)

        if [ -n "$WINDOW_EXISTS" ]; then
            swaymsg "[con_id=\"$WINDOW_EXISTS\"] focus"
        else
            swaymsg "workspace \"$WORKSPACE\""
            $LAUNCH_CMD &
        fi
      '';

      session-apps =
        let
          ordered = lib.attrsToList workspaces;
        in
        pkgs.writeShellScriptBin "session-apps" ''
          #!/usr/bin/env bash
          ${lib.concatMapStringsSep "\nsleep 1.5\n" (
            e: "launch-or-focus ${lib.escapeShellArg e.value.app} ${e.value.name} ${e.value.launch}"
          ) ordered}

          sleep 1.5
          swaymsg "workspace ${workspaces."1".name}"
        '';

      power-menu = pkgs.writeShellScriptBin "power-menu" ''
        #!/usr/bin/env bash
        CHOICE=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | ${config.launcher.dmenu} --prompt-text "power")
        [ -z "$CHOICE" ] && exit
        case "$CHOICE" in
          Lock)     swaylock -f ;;
          Logout)   swaymsg exit ;;
          Suspend)  swaylock -f && systemctl suspend ;;
          Reboot)   systemctl reboot ;;
          Shutdown) systemctl poweroff ;;
        esac
      '';

      keybindings-help = pkgs.writeShellScriptBin "keybindings-help" ''
        #!/usr/bin/env bash
        printf '%s\n' \
          "Mod4+Return          terminal" \
          "Mod4+space           app launcher" \
          "Mod4+w                kill focused window" \
          "Mod4+grave            swayr: switch window (fuzzy)" \
          "Mod4+v                clipboard history" \
          "Mod4+Shift+r          rename workspace" \
          "Mod4+Shift+d          display mode picker" \
          "Mod4+Ctrl+1/2/3       display mode: single/docked/triple" \
          "Mod4+Ctrl+Left/Right  move workspace to adjacent output" \
          "Mod4+minus            show scratchpad" \
          "Mod4+Shift+minus      send to scratchpad" \
          "Mod4+Shift+s          screenshot (region, gui)" \
          "Mod4+Shift+x          screenshot (full, to clipboard)" \
          "Mod4+Shift+e          power menu" \
          "Mod4+Escape           lock" \
          "Mod4+1..0             go to workspace number" \
          "Mod4+f/e/a/n          launch or focus: Web (zen)/Files (superfile)/Agents (zellij)/Notes (zennotes)" \
          | ${config.launcher.dmenu} --require-match false --prompt-text "keys"
      '';

      volume-notify = pkgs.writeShellScriptBin "volume-notify" ''
        #!/usr/bin/env bash
        case "''${1:-}" in
          up)   wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
          down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
          mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
          mic)
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            MIC=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
            if echo "$MIC" | grep -q MUTED; then
              notify-send -t 1500 -c volume \
                -h string:x-canonical-private-synchronous:mic \
                "Microphone" "Muted"
            else
              notify-send -t 1500 -c volume \
                -h string:x-canonical-private-synchronous:mic \
                "Microphone" "Unmuted"
            fi
            exit 0
            ;;
        esac
        INFO=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
        VOL=$(echo "$INFO" | awk '{print int($2 * 100)}')
        if echo "$INFO" | grep -q MUTED; then
          notify-send -t 1500 -c volume \
            -h string:x-canonical-private-synchronous:volume \
            -h int:value:0 \
            "Volume" "Muted"
        else
          notify-send -t 1500 -c volume \
            -h string:x-canonical-private-synchronous:volume \
            -h int:value:"$VOL" \
            "Volume" "$VOL%"
        fi
      '';

      brightness-notify = pkgs.writeShellScriptBin "brightness-notify" ''
        #!/usr/bin/env bash
        case "''${1:-}" in
          up)   brillo -A 5 ;;
          down) brillo -U 5 ;;
        esac
        BRI=$(brillo | awk '{print int($1 + 0.5)}')
        notify-send -t 1500 -c brightness \
          -h string:x-canonical-private-synchronous:brightness \
          -h int:value:"$BRI" \
          "Brightness" "$BRI%"
      '';

      rename-workspace = pkgs.writeShellScriptBin "rename-workspace" ''
        #!/usr/bin/env bash
        WS=$(swaymsg -t get_workspaces | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
        NUM=$(echo "$WS" | grep -oP '^\d+')
        default_name() { echo "$1"; }

        LABEL=$(echo | ${config.launcher.dmenu} --require-match false --prompt-text "New name:")
        if [ -z "$LABEL" ]; then
          [ -n "$NUM" ] && swaymsg rename workspace to "$(default_name "$NUM")"
          exit 0
        fi
        if [ -n "$NUM" ]; then
          swaymsg rename workspace to "$NUM: $LABEL"
        else
          swaymsg rename workspace to "$LABEL"
        fi
      '';

      swap-workspace-output = pkgs.writeShellScriptBin "swap-workspace-output" ''
            #!/usr/bin/env bash
            set -euo pipefail

            DIRECTION="''${1:-}"
            case "$DIRECTION" in
              left|right) ;;
              *)
                echo "Usage: swap-workspace-output left|right" >&2
                exit 1
                ;;
            esac

            CUR_OUT=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
            CUR_WS=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .current_workspace // empty')

            [ -n "$CUR_WS" ] || exit 0

            swaymsg focus output "$DIRECTION" >/dev/null
            ADJ_OUT=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
            ADJ_WS=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .current_workspace // empty')

            if [ "$ADJ_OUT" = "$CUR_OUT" ] || [ -z "$ADJ_WS" ]; then
              swaymsg focus output "$CUR_OUT" >/dev/null
              swaymsg workspace "$CUR_WS" >/dev/null
              exit 0
            fi

            swaymsg move workspace to output "$CUR_OUT" >/dev/null
            swaymsg focus output "$CUR_OUT" >/dev/null
            swaymsg workspace "$CUR_WS" >/dev/null
            swaymsg move workspace to output "$ADJ_OUT" >/dev/null

            swaymsg focus output "$CUR_OUT" >/dev/null
            swaymsg workspace "$ADJ_WS" >/dev/null

            eval "$(${pkgs.jq}/bin/jq -r --arg out "$CUR_OUT" '
              .[] | select(.name == $out) |
              "CURSOR_X=\(.rect.x + .rect.width / 2 | floor)
        CURSOR_Y=\(.rect.y + .rect.height / 2 | floor)"
            ' < <(swaymsg -t get_outputs))"
            swaymsg seat seat0 cursor set "$CURSOR_X" "$CURSOR_Y" >/dev/null
      '';

      screencast-idle-inhibit = pkgs.writeShellScriptBin "screencast-idle-inhibit" ''
        #!/usr/bin/env bash
        set -uo pipefail

        INHIBIT_PID=""

        casting() {
          ${pkgs.pipewire}/bin/pw-dump 2>/dev/null | ${pkgs.jq}/bin/jq -e '
            [ .[]
              | select(.type == "PipeWire:Interface:Node")
              | select((.info.props."node.name" // "") | startswith("xdpw-stream-"))
            ] | length > 0' >/dev/null
        }

        release() {
          if [ -n "$INHIBIT_PID" ]; then
            kill "$INHIBIT_PID" 2>/dev/null || true
            INHIBIT_PID=""
          fi
        }
        trap 'release; exit 0' TERM INT

        while true; do
          if casting; then
            if [ -z "$INHIBIT_PID" ] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
              systemd-inhibit --what=idle \
                --who="screencast-idle-inhibit" \
                --why="Screen sharing in progress" \
                sleep infinity &
              INHIBIT_PID=$!
            fi
          else
            release
          fi
          sleep 5
        done
      '';
    in
    {
      options.desktop.borderWidth = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Sway window border width (px). Other UI chrome (fuzzel, etc.) matches this.";
      };

      imports = with top.config.flake.modules.homeManager; [
        desktop-sway-waybar
        desktop-sway-overview
        desktop-sway-kanshi
        desktop-sway-mako
        desktop-sway-swaylock
        desktop-sway-fuzzel
        desktop-sway-bluetooth
      ];

      config = {

        services.cliphist = {
          enable = true;
          allowImages = true;
        };

        home.packages = with pkgs; [
          alacritty
          wdisplays
          j
          nice-dcv-client
          swayr
          jq
          autotiling-rs
          lxqt.lxqt-policykit

          # flameshot installed via services.flameshot below
          grim
          slurp
          wl-clipboard
          xdg-utils
          wifitui

          launch-or-focus
          session-apps
          power-menu
          rename-workspace
          keybindings-help
          swap-workspace-output
          volume-notify
          brightness-notify
          screencast-idle-inhibit
        ];

        xdg.configFile."environment.d/xdg.conf".text = ''
          XDG_SESSION_TYPE=wayland
          XDG_CURRENT_DESKTOP=sway
        '';

        # Flameshot service (must run as daemon on Wayland)
        services.flameshot = {
          enable = true;
          settings = {
            General = {
              showStartupLaunchMessage = false;
            };
          };
        };

        # swayr's picker menu, pointed at fuzzel instead of its wofi default.
        # See https://git.sr.ht/~tsdh/swayr#the-menu-section
        xdg.configFile."swayr/config.toml".text = ''
          [menu]
          executable = '${lib.getExe pkgs.fuzzel}'
          args = [
              '--dmenu',
              '--prompt={prompt}',
          ]

          [format]
          output_format = '{indent}Output {name}    ({id})'
          workspace_format = '{indent}Workspace {name} [{layout}]    ({id})'
          container_format = '{indent}Container [{layout}] on workspace {workspace_name} {marks}    ({id})'
          window_format = '{indent}{app_name} — {urgency_start}"{title}"{urgency_end} on workspace {workspace_name} {marks}    ({id})'
          indent = '    '
          urgency_start = '''
          urgency_end = '''
          html_escape = false
        '';

        wayland.windowManager.sway = {
          enable = true;
          package = pkgs.sway;
          checkConfig = false;

          config = {
            modifier = "Mod4";
            left = "h";
            down = "j";
            up = "k";
            right = "l";
            terminal = "alacritty";
            menu = config.launcher.drun;

            fonts = {
              names = [ config.stylix.fonts.monospace.name ];
              size = lib.mkForce (config.stylix.fonts.sizes.desktop * 1.0);
            };

            window = {
              border = 4;
              hideEdgeBorders = "none";
            };

            floating = {
              border = 4;
              modifier = "Mod4";
            };

            gaps = {
              inner = 15;
              outer = 15;
              smartGaps = "on";
              smartBorders = "on";
            };

            colors = lib.mkForce {
              focused = {
                border = "#${colors.base0D}";
                background = "#${colors.base0D}";
                text = "#${colors.base00}";
                indicator = "#${colors.base04}";
                childBorder = "#${colors.base0D}";
              };
              focusedInactive = {
                border = "#${colors.base02}";
                background = "#${colors.base0D}";
                text = "#${colors.base00}";
                indicator = "#${colors.base03}";
                childBorder = "#${colors.base01}";
              };
              unfocused = {
                border = "#${colors.base01}";
                background = "#${colors.base01}";
                text = "#${colors.base06}";
                indicator = "#${colors.base01}";
                childBorder = "#${colors.base01}";
              };
              urgent = {
                border = "#${colors.base08}";
                background = "#${colors.base01}";
                text = "#${colors.base08}";
                indicator = "#${colors.base08}";
                childBorder = "#${colors.base08}";
              };
              placeholder = {
                border = "#${colors.base01}";
                background = "#${colors.base01}";
                text = "#${colors.base03}";
                indicator = "#${colors.base01}";
                childBorder = "#${colors.base01}";
              };
              background = "#${colors.base01}";
            };

            assigns = lib.mapAttrs' (_: v: lib.nameValuePair v.name [ { app_id = v.app; } ]) workspaces;

            window.commands = [
              {
                criteria = {
                  app_id = "flameshot";
                };
                command = "fullscreen enable global, floating enable, border none";
              }

            ];

            input = {
              "type:keyboard" = {
                xkb_layout = "us,es";
                xkb_options = "caps:ctrl_modifier,grp:alt_space_toggle";
              };
              "type:touchpad" = {
                natural_scroll = "enabled";
                tap = "enabled";
                dwt = "enabled";
              };
            };

            seat = {
              seat0 = {
                xcursor_theme = "${cursorName} ${cursorSize}";
              };
            };

            bindswitches = {
              "lid:on" = {
                action = "exec swaylock -f && systemctl suspend";
                reload = true;
                locked = true;
              };
            };

            startup = [

              {
                command = "swayidle -w timeout 300 'swaylock -f' timeout 600 'swaymsg \"output * power off\"' resume 'swaymsg \"output * power on\"' before-sleep 'swaylock -f'";
              }

              {
                command = "${screencast-idle-inhibit}/bin/screencast-idle-inhibit";
              }

              {
                command = "export XCURSOR_THEME=${cursorName}";
                always = true;
              }
              {
                command = "export XCURSOR_SIZE=${cursorSize}";
                always = true;
              }

              { command = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent"; }

              { command = "${pkgs.swayr}/bin/swayrd"; }

              { command = "autotiling-rs"; }

              {
                command = "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway XCURSOR_THEME XCURSOR_SIZE";
              }
              {
                command = "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XCURSOR_THEME XCURSOR_SIZE";
              }
              {
                command = "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP";
              }
              {
                command = "hash dbus-update-activation-environment 2>/dev/null && dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP";
              }

              {
                command = "gsettings set org.gnome.desktop.interface cursor-theme '${cursorName}'";
                always = true;
              }
              {
                command = "gsettings set org.gnome.desktop.interface cursor-size ${cursorSize}";
                always = true;
              }

              { command = "${session-apps}/bin/session-apps"; }
            ];

            # Mod4          = act / navigate / launch
            # Mod4+Shift     = move / secondary variant of the bare action
            # Mod4+Ctrl      = system & hardware (displays, gaps, streaming)
            keybindings = {

              "Mod4+Return" = "exec alacritty";
              "Mod4+w" = "kill";

              "Mod4+p" = "floating enable, sticky enable";
              "Mod4+space" = "exec ${config.launcher.drun}";
              "Mod4+Shift+c" = "reload";
              "Mod4+Shift+e" = "exec power-menu";
              "Mod4+Escape" = "exec swaylock -f";

              "XF86MonBrightnessUp" = "exec brightness-notify up";
              "XF86MonBrightnessDown" = "exec brightness-notify down";

              "XF86AudioRaiseVolume" = "exec volume-notify up";
              "XF86AudioLowerVolume" = "exec volume-notify down";
              "XF86AudioMute" = "exec volume-notify mute";
              "XF86AudioMicMute" = "exec volume-notify mic";

              "Mod4+Shift+s" = "exec flameshot gui";
              "Mod4+Shift+x" = "exec grim - | wl-copy";
              "Mod4+Shift+a" = "exec grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png";

              "Mod4+v" =
                "exec sh -c 'cliphist list | ${config.launcher.dmenu} --prompt-text \"clip\" | cliphist decode | wl-copy'";

              "Mod4+h" = "focus left";
              "Mod4+j" = "focus down";
              "Mod4+k" = "focus up";
              "Mod4+l" = "focus right";
              "Mod4+Left" = "focus left";
              "Mod4+Down" = "focus down";
              "Mod4+Up" = "focus up";
              "Mod4+Right" = "focus right";

              "Mod4+Shift+h" = "move left";
              "Mod4+Shift+j" = "move down";
              "Mod4+Shift+k" = "move up";
              "Mod4+Shift+l" = "move right";
              "Mod4+Shift+Left" = "move left";
              "Mod4+Shift+Down" = "move down";
              "Mod4+Shift+Up" = "move up";
              "Mod4+Shift+Right" = "move right";

              "Mod4+Shift+b" = "splith";
              "Mod4+Shift+v" = "splitv";
              "Mod4+u" = "layout stacking";
              "Mod4+i" = "layout tabbed";
              "Mod4+o" = "layout toggle split";
              "Mod4+Shift+f" = "fullscreen";
              "Mod4+Shift+space" = "floating toggle";
              "Mod4+a" = "focus parent";

              "Mod4+Shift+minus" = "move scratchpad";
              "Mod4+minus" = "scratchpad show";

              "Mod4+Shift+r" = "exec rename-workspace";

              "Mod4+Shift+d" = "exec display-mode-selector";
              "Mod4+Ctrl+1" = "exec kanshi-switch single";
              "Mod4+Ctrl+2" = "exec kanshi-switch docked";
              "Mod4+Ctrl+3" = "exec kanshi-switch triple";

              "Mod4+Ctrl+Left" = "exec swap-workspace-output left";
              "Mod4+Ctrl+Right" = "exec swap-workspace-output right";

              "Mod4+Ctrl+equal" = "gaps inner current plus 4";
              "Mod4+Ctrl+minus" = "gaps inner current minus 4";
              "Mod4+Ctrl+Shift+equal" = "gaps outer current plus 4";
              "Mod4+Ctrl+Shift+minus" = "gaps outer current minus 4";
              "Mod4+Ctrl+0" = "gaps inner current set 0, gaps outer current set 0";
              "Mod4+Ctrl+9" = "gaps inner current set 8, gaps outer current set 4";

              "Mod4+r" = "mode resize";

              "Mod4+grave" = "exec ${pkgs.swayr}/bin/swayr switch-window";
              "Mod4+Shift+slash" = "exec keybindings-help";
            }

            // lib.listToAttrs (
              lib.concatMap (
                n:
                let
                  key = if n == "10" then "0" else n;
                in
                [
                  (lib.nameValuePair "Mod4+${key}" "workspace number ${n}")
                  (lib.nameValuePair "Mod4+Shift+${key}" "move container to workspace number ${n}")
                ]
              ) (map toString (lib.range 1 10))
            )
            // lib.mapAttrs' (
              _: v: lib.nameValuePair "Mod4+${v.key}" "exec launch-or-focus ${lib.escapeShellArg v.app} ${v.name} ${v.launch}"
            ) workspaces;

            modes = {
              resize = {
                h = "resize shrink width 10px";
                j = "resize grow height 10px";
                k = "resize shrink height 10px";
                l = "resize grow width 10px";
                Left = "resize shrink width 10px";
                Down = "resize grow height 10px";
                Up = "resize shrink height 10px";
                Right = "resize grow width 10px";
                Return = "mode default";
                Escape = "mode default";
              };
            };
          };

          extraConfig = ''
            titlebar_border_thickness 0
            titlebar_padding 0 0

            output * bg #${colors.base00} solid_color
            default_border pixel ${toString config.desktop.borderWidth}

            bindgesture swipe:4:left workspace prev
            bindgesture swipe:4:right workspace next

            include /etc/sway/config-vars.d/*
            include /etc/sway/config.d/*
          '';
        };

      };
    };
}
