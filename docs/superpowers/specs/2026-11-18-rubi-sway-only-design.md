# Rubi: return to Sway-only (drop yami)

## Goal

Make rubi’s desktop **Sway-only**. Remove yami/niri from the flake, host, and home-manager config. Also undo dual-session clash workarounds that only existed because sway and yami shared a user session stack.

## Non-goals

- No change to theme-switch behavior, Stylix, waybar, kanshi, or other sway feature modules beyond comment cleanup and the mako/playerctl restorations below.
- Agents do not deploy; Diego deploys rubi after merge.

## Host / home / flake wiring

### NixOS (rubi)

- Keep `desktop-environments-sway`; remove `desktop-environments-yami` from `parts/nixos/hosts/rubi/default.nix`.
- Set `desktop = "sway"` in `parts/hosts/rubi.nix`.
- Remove `/var/lib/yami-greet/look` and `/var/lib/yami-greet/state` (and their comments) from `parts/nixos/hosts/rubi/impermanence.nix`.
- Delete `parts/nixos/optional/desktop/environments/yami.nix`.
- In `parts/nixos/optional/desktop/environments/sway.nix`, restore comments to describe tuigreet + sway only (no yami greeter override).

### Home (rubi)

- Drop `desktop-yami` from imports in `parts/home/rubi.nix`.
- Set `desktop = "sway"` in `parts/homes.nix`.
- Delete `parts/home/features/desktop/yami/` (entire directory).

### Flake

- Remove the `yami` input from `flake.nix`.
- Refresh `flake.lock` so the yami entry is gone.

## Dual-session cleanup

With no niri/yami session left:

### mako (`parts/home/features/desktop/sway/mako.nix`)

- Use stock `pkgs.mako` again (`services.mako.package` default / unset the null override).
- Drop the bin-only wrapper that prevented D-Bus auto-start under niri.
- Keep the existing sway `startup` entry that runs `mako` so notifications are available at session start. Do not reintroduce yami-specific D-Bus guards.

### playerctl (`parts/home/features/desktop/common/playerctl.nix`)

- Use stock `pkgs.playerctl` (no overlay that deletes the D-Bus service file).
- Remove sway’s explicit `{ command = ".../playerctld"; }` startup entry so D-Bus activation is the single start path.

### Conditionals and comments

- In `parts/home/features/desktop/common/default.nix`, drop `desktop == "yami"`; keep cursor-theme for `desktop == "sway"`.
- Rewrite or delete yami/niri-only comments in:
  - `parts/home/features/desktop/sway/default.nix`
  - `parts/home/features/desktop/sway/mako.nix`
  - `parts/home/features/desktop/common/playerctl.nix`
  - `parts/home/features/desktop/common/udiskie.nix`
  - `parts/home/features/desktop/common/theme-switch.nix`
  - related flameshot / portal comments that only explain niri coexistence

## Verification

- `nix flake check --no-build`
- `nix build .#nixosConfigurations.rubi.config.system.build.toplevel`

## Success criteria

- rubi evaluates and builds with Sway as the only desktop environment module.
- No `yami` input, modules, or impermanence paths remain.
- mako and playerctl use stock packages without yami clash overlays.
