{ ... }:
{
  # One ZenNotes theme with rubi's two schemes: colors-light under :root and
  # colors under [data-theme-mode="dark"]. With theme_mode "auto" the app
  # follows the system setting, which darkman switches. Fonts come from
  # config.toml (interface_font, text_font, mono_font), not from the theme.
  flake.modules.homeManager.desktop-zennotes-theme =
{ config, lib, pkgs, inputs, ... }:
let
  pair = import ../../modules/_colorschemes/colors-pair.nix { inherit inputs lib pkgs; };

  # ZenNotes tokens are space-separated RGB triplets.
  hexToRgb =
    hex:
    let
      n = lib.trivial.fromHexString hex;
      r = n / 65536;
      g = (n / 256) - (r * 256);
      b = n - (r * 65536) - (g * 256);
    in
    "${toString r} ${toString g} ${toString b}";

  vars = colors: shadow: let c = builtins.mapAttrs (_: hexToRgb) colors; in ''
      --z-bg: ${c.base00};
      --z-bg-softer: ${c.base00};
      --z-bg-1: ${c.base01};
      --z-bg-2: ${c.base02};
      --z-bg-3: ${c.base03};
      --z-bg-4: ${c.base04};

      --z-fg: ${c.base05};
      --z-fg-1: ${c.base06};
      --z-fg-2: ${c.base04};
      --z-grey-2: ${c.base04};
      --z-grey-1: ${c.base03};
      --z-grey-0: ${c.base02};
      --z-grey-dim: ${c.base01};

      --z-accent: ${c.base0D};
      --z-accent-soft: ${c.base09};
      --z-accent-muted: ${c.base0B};

      --z-red: ${c.base08};
      --z-green: ${c.base0B};
      --z-yellow: ${c.base0A};
      --z-blue: ${c.base0D};
      --z-purple: ${c.base0E};
      --z-aqua: ${c.base0C};

      --z-shadow: ${c.${shadow}};
  '';

  themeCss = ''
    :root {
      color-scheme: light;
    ${vars pair.light "base07"}
    }
    :root[data-theme-mode="dark"] {
      color-scheme: dark;
    ${vars pair.dark "base00"}
    }
  '';

  manifest = builtins.toJSON {
    name = "Colors";
    author = "nix-config";
    version = "1.0.0";
    description = "colors (dark) and colors-light, rubi's terminal and desktop schemes.";
    modes = "both";
    preview = {
      light = "#${pair.light.base0D}";
      dark = "#${pair.dark.base0D}";
    };
  };
in
{
  xdg.configFile."zennotes/themes/colors/manifest.json".text = manifest;
  xdg.configFile."zennotes/themes/colors/theme.css".text = themeCss;

  # config.toml also holds preferences the app writes, so only the three theme
  # keys are set here, not the whole file. A rebuild resets a theme picked in
  # the app back to this one.
  home.activation.zennotesTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="${config.xdg.configHome}/zennotes/config.toml"
    if [ -f "$f" ] && [ ! -L "$f" ]; then
      run ${pkgs.gnused}/bin/sed -i -E \
        -e 's/^theme_family = .*/theme_family = "custom"/' \
        -e 's/^theme_id = .*/theme_id = "custom-colors"/' \
        -e 's/^theme_mode = .*/theme_mode = "auto"/' "$f"
    fi
  '';
};
}
