{ ... }:
{
  flake.modules.homeManager.desktop-common-playerctl =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.playerctl
        pkgs.lyrics
      ];
    };
}