{ ... }:
{
  # niri + yami, with sway left installed by desktop-environments-sway.
  # Stock nixpkgs niri: programs.yami enables programs.niri and does not
  # pull yami's patched compositor (docs/PACKAGING.md).
  flake.modules.nixos.desktop-environments-yami =
    { config, lib, pkgs, inputs, ... }:
    {
      imports = [ inputs.yami.nixosModules.default ];

      # yami's system package list includes playerctl. Its D-Bus service starts
      # playerctld in every session, including niri, where yami is the MPRIS
      # client. sway starts the daemon from its own config.
      nixpkgs.overlays = [
        (final: prev: {
          playerctl = prev.playerctl.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              rm -f $out/share/dbus-1/services/org.mpris.MediaPlayer2.playerctld.service
            '';
          });
        })
      ];

      programs.yami = {
        enable = true;
        # Whose shell may write /var/lib/yami-greet/look (palette, font, wallpaper).
        loginScreen.user = "diego";
        # Stylix owns GTK/Qt. qt6ct + adw-gtk3 are only there for `yami recolor`.
        appTheme = false;
        # alacritty is the terminal. kitty, fastfetch and the rest stay out.
        apps = false;
      };

      # The greeter user has no home-manager fontconfig. Jost is the sans
      # family from desktop-common-stylix; without it on the system path
      # fc-match fails and yami-greet keeps Tiny5.
      fonts.packages = [ pkgs.jost ];

      # yami's greet-session looks up fonts with fc-match and, after two
      # failed starts, falls back to agreety. Neither is on the PATH its
      # NixOS module builds (niri, coreutils, util-linux, systemd).
      # fontconfig is built with --sysconfdir=/etc, so this fc-match reads
      # NixOS's fontconfig, including fonts.packages above.
      # mkForce: desktop-environments-sway also sets this command (tuigreet,
      # sway sessions only).
      services.greetd.settings.default_session.command = lib.mkForce "${pkgs.writeShellScript "yami-greet-session-rubi" ''
        export PATH=${
          lib.makeBinPath [
            config.programs.niri.package
            pkgs.fontconfig
            pkgs.greetd
            pkgs.coreutils
            pkgs.util-linux
            pkgs.systemd
          ]
        }:$PATH
        export XDG_DATA_DIRS=${config.services.displayManager.sessionData.desktops}/share
        exec ${config.programs.yami.package}/libexec/yami/greet-session
      ''}";
    };
}
