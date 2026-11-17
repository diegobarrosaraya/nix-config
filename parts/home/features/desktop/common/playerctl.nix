{ ... }:
{
  flake.modules.homeManager.desktop-common-playerctl =
    { pkgs, ... }:
    let
      # playerctl ships org.mpris.MediaPlayer2.playerctld.service, which
      # starts the daemon in every session the moment something asks for
      # that name. yami reads MPRIS itself; playerctld would show up as
      # another player. sway starts the daemon from its own config.
      playerctl = pkgs.playerctl.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          rm -f $out/share/dbus-1/services/org.mpris.MediaPlayer2.playerctld.service
        '';
      });
    in
    {
      home.packages = [
        playerctl
        pkgs.lyrics
      ];
    };
}
