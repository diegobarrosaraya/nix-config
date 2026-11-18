{ ... }:
{
  flake.modules.homeManager.desktop-common-udiskie =
{ pkgs, ... }: {
  xdg.configFile."udiskie/config.yml".text = ''
    program_options:
      automount: true
      notify: true
      tray: false
  '';

  # Automount on sway-session.target.
  systemd.user.services.udiskie = {
    Unit = {
      Description = "udiskie automounter";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.udiskie}/bin/udiskie";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };
};}
