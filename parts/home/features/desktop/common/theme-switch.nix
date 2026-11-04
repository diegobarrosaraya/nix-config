{ ... }:
{
  # Light/dark switching on top of colorscheme.specialisations. Stylix themes at
  # build time, so a switch activates the other home-manager specialisation.
  # `theme light|dark|toggle` does it by hand; darkman does it at sunrise and
  # sunset. The choice is kept in ~/.local/state/theme.
  flake.modules.homeManager.desktop-common-theme-switch =
{ config, lib, pkgs, ... }:
let
  state = "${config.xdg.stateHome}/theme";

  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = with pkgs; [ coreutils gnugrep sway mako ];
    text = ''
      # Mode of the generation this script came from, so of the active one.
      current=${config.colorscheme.mode}
      case "''${1:-toggle}" in
        light | dark) want=$1 ;;
        toggle) if [ "$current" = dark ]; then want=light; else want=dark; fi ;;
        *) echo "usage: theme [light|dark|toggle]" >&2; exit 2 ;;
      esac
      mkdir -p "$(dirname ${state})"
      echo "$want" > ${state}
      [ "$want" = "$current" ] && exit 0

      # A specialisation's activation becomes the newest home-manager
      # generation, so the profile cannot lead back to the base. The NixOS
      # unit always runs the base generation of the current system.
      base=$(grep -oE '/nix/store/[a-z0-9]+-home-manager-generation' \
        /etc/systemd/system/home-manager-${config.home.username}.service | head -n1)
      if [ -x "$base/specialisation/$want/activate" ]; then
        "$base/specialisation/$want/activate"
      else
        # No specialisation for this mode: the base generation is it.
        "$base/activate"
      fi

      # Alacritty and waybar (a systemd unit) pick up the change by themselves.
      swaymsg reload >/dev/null 2>&1 || true
      makoctl reload >/dev/null 2>&1 || true
    '';
  };
in
lib.mkIf (config.colorscheme.specialisations != { }) {
  home.packages = [ theme ];

  # A rebuild activates the base generation and would drop a light choice.
  # Only the base has specialisations, so this never runs inside one.
  home.activation.applySavedTheme = lib.mkIf (config.specialisation != { }) (
    lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" "onFilesChange" "reloadSystemd" ] ''
      saved=$(cat ${state} 2>/dev/null || true)
      if [ -n "$saved" ] && [ "$saved" != ${config.colorscheme.mode} ] \
        && [ -x "$newGenPath/specialisation/$saved/activate" ]; then
        run "$newGenPath/specialisation/$saved/activate"
      fi
    ''
  );

  services.darkman = {
    enable = true;
    # Santiago. Geoclue is off on rubi (see its host config), so fixed coordinates.
    settings = {
      lat = -33.45;
      lng = -70.67;
      usegeoclue = false;
    };
    darkModeScripts.theme = "${lib.getExe theme} dark";
    lightModeScripts.theme = "${lib.getExe theme} light";
  };
};
}
