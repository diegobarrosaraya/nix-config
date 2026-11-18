# Rubi Sway-only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make rubi Sway-only by removing yami/niri from the flake, host, and home config, and restoring stock mako/playerctl.

**Architecture:** Disconnect rubi from yami modules, delete those modules and the flake input, scrub yami/niri dual-session comments and conditionals, then verify with `nix flake check --no-build` and a rubi toplevel build.

**Tech Stack:** Nix flakes, flake-parts (dendritic modules), NixOS, home-manager, Sway, greetd/tuigreet.

## Global Constraints

- Public repo: do not add secrets or customer names.
- Follow neighbouring file patterns; no `hosts/common/` or `modules/home-manager/`.
- `git add` new/changed files before any `nix` command (flakes see tracked files only).
- Do not deploy; Diego deploys rubi after merge.
- Conventional commits; no AI/model/tool names in commit messages.
- Spec: `docs/superpowers/specs/2026-11-18-rubi-sway-only-design.md`.

---

## File map

| Path | Action |
|------|--------|
| `flake.nix` | Remove `yami` input |
| `flake.lock` | Refresh after input removal |
| `parts/hosts/rubi.nix` | `desktop = "sway"` |
| `parts/homes.nix` | `desktop = "sway"` |
| `parts/nixos/hosts/rubi/default.nix` | Drop yami import + comment |
| `parts/nixos/hosts/rubi/impermanence.nix` | Drop yami-greet dirs |
| `parts/nixos/optional/desktop/environments/yami.nix` | Delete |
| `parts/nixos/optional/desktop/environments/sway.nix` | Comment cleanup |
| `parts/home/rubi.nix` | Drop `desktop-yami` |
| `parts/home/features/desktop/yami/` | Delete |
| `parts/home/features/desktop/sway/mako.nix` | Stock mako |
| `parts/home/features/desktop/common/playerctl.nix` | Stock playerctl |
| `parts/home/features/desktop/sway/default.nix` | Drop playerctld startup; comment cleanup |
| `parts/home/features/desktop/common/default.nix` | Drop `desktop == "yami"` |
| `parts/home/features/desktop/common/udiskie.nix` | Comment cleanup |
| `parts/home/features/desktop/common/theme-switch.nix` | Comment cleanup |

---

### Task 1: Point rubi at sway and remove yami modules/input

**Files:**
- Modify: `parts/hosts/rubi.nix`
- Modify: `parts/homes.nix`
- Modify: `parts/nixos/hosts/rubi/default.nix`
- Modify: `parts/nixos/hosts/rubi/impermanence.nix`
- Modify: `parts/home/rubi.nix`
- Modify: `flake.nix`
- Delete: `parts/nixos/optional/desktop/environments/yami.nix`
- Delete: `parts/home/features/desktop/yami/default.nix` (and directory)
- Modify: `flake.lock` (via `nix flake lock --update-input` removal / `nix flake lock`)

**Interfaces:**
- Consumes: existing `desktop-environments-sway`, `desktop-sway`
- Produces: rubi with `desktop = "sway"` and no yami module references

- [ ] **Step 1: Set desktop to sway on host and homeConfigurations**

In `parts/hosts/rubi.nix`, change:

```nix
desktop = "sway";
```

In `parts/homes.nix` under `"diego@rubi"`, change:

```nix
desktop = "sway";
```

- [ ] **Step 2: Drop yami from rubi NixOS imports**

In `parts/nixos/hosts/rubi/default.nix`, replace the dual-session import block with:

```nix
    desktop-environments-sway
```

Remove the comment about sway as fallback / yami mkForce.

- [ ] **Step 3: Drop desktop-yami from home rubi**

In `parts/home/rubi.nix` imports, remove `desktop-yami` so the desktop imports are:

```nix
        desktop-common
        desktop-sway
        desktop-zennotes-theme
```

- [ ] **Step 4: Remove yami-greet impermanence paths**

In `parts/nixos/hosts/rubi/impermanence.nix`, delete the comment block and both directory entries for `/var/lib/yami-greet/look` and `/var/lib/yami-greet/state`. Leave neighbouring entries (`/var/lib/lockdown`, `/home/diego`) unchanged.

- [ ] **Step 5: Remove yami flake input**

In `flake.nix`, delete the entire `yami` attribute and its comment (the block starting with `# Pinned release...` through the closing `};` of `yami`).

- [ ] **Step 6: Delete yami module files**

```bash
git rm parts/nixos/optional/desktop/environments/yami.nix
git rm -r parts/home/features/desktop/yami
```

- [ ] **Step 7: Refresh flake.lock**

```bash
git add flake.nix parts/hosts/rubi.nix parts/homes.nix parts/nixos/hosts/rubi/default.nix parts/nixos/hosts/rubi/impermanence.nix parts/home/rubi.nix
nix flake lock
```

Confirm `flake.lock` no longer contains a `"yami"` node (search the lock file). Stage `flake.lock`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(rubi): drop yami and set desktop to sway

Remove the yami flake input and modules, point rubi host and
home at sway, and drop yami-greet impermanence paths.
EOF
)"
```

---

### Task 2: Restore stock mako and playerctl; scrub dual-session comments

**Files:**
- Modify: `parts/home/features/desktop/sway/mako.nix`
- Modify: `parts/home/features/desktop/common/playerctl.nix`
- Modify: `parts/home/features/desktop/sway/default.nix`
- Modify: `parts/nixos/optional/desktop/environments/sway.nix`
- Modify: `parts/home/features/desktop/common/default.nix`
- Modify: `parts/home/features/desktop/common/udiskie.nix`
- Modify: `parts/home/features/desktop/common/theme-switch.nix`

**Interfaces:**
- Consumes: Task 1 sway-only wiring
- Produces: stock mako/playerctl; sway startup runs mako only (not playerctld)

- [ ] **Step 1: Restore stock mako**

Replace `parts/home/features/desktop/sway/mako.nix` with:

```nix
{ ... }:
{
  flake.modules.homeManager.desktop-sway-mako =
{ config, pkgs, ... }:
let
  inherit (config.colorscheme) colors;
  inherit (config.stylix) fonts;
in
{
  services.mako = {
    enable = true;
    settings = {
      font = "${fonts.sansSerif.name} 14";
      max-visible = 5;
      sort = "-time";
      layer = "overlay";
      anchor = "top-right";
      margin = "10";
      padding = "12";
      width = 350;
      height = 120;
      border-size = 2;
      border-radius = 0;
      icons = 1;
      icon-path = "/usr/share/icons/Papirus-Dark";
      max-icon-size = 48;
      default-timeout = 5000;
      ignore-timeout = 0;
      background-color = "#${colors.base00}FF";
      text-color = "#${colors.base05}";
      border-color = "#${colors.base02}";
      progress-color = "over #${colors.base0C}";

      "urgency=low" = {
        background-color = "#${colors.base00}FF";
        text-color = "#${colors.base04}";
        border-color = "#${colors.base01}";
        default-timeout = 3000;
      };

      "urgency=normal" = {
        background-color = "#${colors.base00}FF";
        text-color = "#${colors.base05}";
        border-color = "#${colors.base0D}";
        default-timeout = 5000;
      };

      "urgency=critical" = {
        background-color = "#${colors.base0F}";
        text-color = "#${colors.base00}";
        border-color = "#${colors.base08}";
        default-timeout = 0;
      };

      "category=volume" = {
        default-timeout = 1500;
        height = 60;
        border-color = "#${colors.base0C}";
      };

      "category=brightness" = {
        default-timeout = 1500;
        height = 60;
        border-color = "#${colors.base0A}";
      };
    };
  };
};
}
```

(No `package = null`, no bin-only wrapper, no `home.packages = [ mako ]`.)

- [ ] **Step 2: Restore stock playerctl**

Replace `parts/home/features/desktop/common/playerctl.nix` with:

```nix
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
```

- [ ] **Step 3: Update sway startup and comments**

In `parts/home/features/desktop/sway/default.nix`:

1. Replace the cliphist comment with a short sway-only note, e.g. that cliphist binds to `sway-session.target`.
2. Replace the environment.d / XDG_CURRENT_DESKTOP / flameshot comments that mention niri with sway-only wording (flameshot is forced onto `sway-session.target`).
3. In `startup`, keep mako, remove playerctld:

```nix
            startup = [
              { command = "${pkgs.mako}/bin/mako"; }

              {
                command = "swayidle -w timeout 300 'swaylock -f' timeout 600 'swaymsg \"output * power off\"' resume 'swaymsg \"output * power on\"' before-sleep 'swaylock -f'";
              }
```

(Keep the rest of the existing `startup` entries after that.)

- [ ] **Step 4: Clean sway NixOS greeter comment**

In `parts/nixos/optional/desktop/environments/sway.nix`, replace the greeter comment with:

```nix
  # tuigreet with sway's wayland session.
```

- [ ] **Step 5: Drop yami from desktop-common cursor conditional**

In `parts/home/features/desktop/common/default.nix`, change:

```nix
      } // lib.optionalAttrs (desktop == "sway") {
```

- [ ] **Step 6: Scrub remaining yami/niri comments**

In `parts/home/features/desktop/common/udiskie.nix`, replace the yami-agents comment with:

```nix
  # Automount on sway-session.target.
```

In `parts/home/features/desktop/common/theme-switch.nix`, replace the header comment's yami sentence so it only describes specialisations + `theme` + swaymsg/makoctl, for example:

```nix
  # Light/dark switching on top of colorscheme.specialisations. Stylix themes at
  # build time, so a switch activates the other home-manager specialisation.
  # `theme light|dark|toggle` does it by hand. The choice is kept in
  # ~/.local/state/theme. After activation, swaymsg and makoctl refresh the
  # running sway session.
```

Grep the tree for `yami` and `niri` under `parts/` and ensure no leftover references remain except unrelated names if any.

- [ ] **Step 7: Commit**

```bash
git add parts/home/features/desktop/sway/mako.nix \
  parts/home/features/desktop/common/playerctl.nix \
  parts/home/features/desktop/sway/default.nix \
  parts/nixos/optional/desktop/environments/sway.nix \
  parts/home/features/desktop/common/default.nix \
  parts/home/features/desktop/common/udiskie.nix \
  parts/home/features/desktop/common/theme-switch.nix
git commit -m "$(cat <<'EOF'
refactor(rubi): restore stock mako/playerctl after yami removal

Drop dual-session D-Bus workarounds and niri/yami comments now that
sway is the only desktop on rubi.
EOF
)"
```

---

### Task 3: Verify flake and rubi build

**Files:**
- None (verification only)

**Interfaces:**
- Consumes: Tasks 1–2 complete tree
- Produces: evidence that check and rubi toplevel succeed

- [ ] **Step 1: Stage everything flakes need**

```bash
git status
git add -A
```

- [ ] **Step 2: Flake check**

```bash
nix flake check --no-build
```

Expected: exit 0, no evaluation errors mentioning yami or missing modules.

- [ ] **Step 3: Build rubi toplevel**

```bash
nix build .#nixosConfigurations.rubi.config.system.build.toplevel
```

Expected: exit 0; result symlink created.

- [ ] **Step 4: Confirm no yami references**

```bash
rg -n 'yami|desktop-environments-yami|desktop-yami' parts flake.nix flake.lock || true
```

Expected: no matches in those paths (docs under `docs/superpowers/` may still mention yami; that is fine).

- [ ] **Step 5: Push branch**

```bash
git push -u origin HEAD
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `desktop = "sway"` host + homes | Task 1 |
| Drop yami NixOS/home imports | Task 1 |
| Delete yami modules | Task 1 |
| Remove yami flake input + lock | Task 1 |
| Remove yami-greet impermanence | Task 1 |
| Stock mako, keep sway startup | Task 2 |
| Stock playerctl, remove playerctld startup | Task 2 |
| Comment/conditional scrub | Task 2 |
| `nix flake check --no-build` | Task 3 |
| rubi toplevel build | Task 3 |
