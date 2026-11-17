{ ... }:
{
  # Plain yami on top of the Stylix colorscheme. shell.json is merged on every
  # activation (declared keys win); the shell reloads it when the mtime changes,
  # including after `theme light|dark`.
  flake.modules.homeManager.desktop-yami =
    { config, lib, pkgs, inputs, ... }:
    let
      c = config.colorscheme.colors;
      h = name: "#${c.${name}}";
      # Stylix appends * so fontconfig treats the name as a family wildcard.
      # yami asks fc-match for the family and checks the result contains it,
      # so "Jost*" never matches the family "Jost".
      family = name: lib.removeSuffix "*" name;
      sans = family config.stylix.fonts.sansSerif.name;
      mono = family config.stylix.fonts.monospace.name;
      # Sway's background is `output * bg <base00> solid_color`. An empty
      # wallpaper setting makes yami draw its generated pixel wallpaper.
      wallpaper = pkgs.runCommand "yami-solid-${c.base00}.png" { } ''
        ${pkgs.imagemagick}/bin/magick -size 64x64 "xc:#${c.base00}" "$out"
      '';
    in
    {
      imports = [ inputs.yami.homeManagerModules.default ];

      programs.yami = {
        enable = true;
        # yami writes ~/.config/niri/config.kdl itself. A Nix-managed file is
        # a store symlink, which `yami niri connect` refuses to touch.
        kitty = false;
        defaultApplications = false;
        # runtime.nix's apps set is kitty, fastfetch, pavucontrol, btop,
        # ffmpegthumbnailer, bsdtar. playerctl comes from desktop-common-playerctl
        # without its D-Bus activation file, so yami's MPRIS client does not
        # wake playerctld under niri.
        extraPackages = with pkgs; [
          wl-clipboard
          cliphist
          grim
          brightnessctl
          pulseaudio
          glib
          curl
          xwayland-satellite
          wlsunset
          (tesseract.override { enableLanguages = [ "eng" "rus" ]; })
          zbar
        ];
        settings = {
          preset = "plain";
          # shell.json's defaults are the pixel preset (tint 1, glass 0.78,
          # lift 0, reveal dither, iconPixel, blur). style.json copies them
          # through, so an absent key does not fall back to plain's defaults.
          reveal = "fade";
          tint = 0.6;
          glass = 1.0;
          lift = 0.25;
          blurShell = false;
          iconPixel = false;
          # "system" deletes yami's cursor.kdl. Stylix keeps the cursor.
          cursor = "system";
          lite = false;
          fontShell = sans;
          fontFiles = sans;
          fontView = sans;
          # Applied only if gtk/qt/kitty are in themeApps, which they are not.
          fontUi = sans;
          fontMono = mono;
          fontPt = config.stylix.fonts.sizes.applications;
          light = config.colorscheme.mode == "light";
          accent = h "base0D";
          # Slots yami derives from the accent (deep, glow, bright) stay derived.
          colors = {
            bg = h "base00";
            panel = h "base01";
            surface = h "base01";
            surfaceHi = h "base02";
            codeBg = h "base01";
            selection = h "base02";
            border = h "base03";
            dim = h "base03";
            textFaint = h "base03";
            textDim = h "base04";
            text = h "base05";
            textHi = h "base07";
            accent = h "base0D";
            onAccent = h "base00";
            ok = h "base0B";
            warn = h "base0A";
          };
          wallKanji = false;
          wallPixel = 1;
          wallTone = "";
          wallAccent = false;
          wallpaper = "${wallpaper}";
          # "plain" would drop the picture and paint yami's derived theme.
          # The shell does not publish `colors` to the greeter (login.rs KEYS),
          # so the greeter shows this same solid image instead.
          greetWall = "desktop";
          # `yami recolor` skips a program left out. Empty stays empty
          # (unknown names are dropped, missing key means all of them).
          themeApps = [ ];
          browserMenus = false;
        };
      };

      # Antialiasing, hinting and Tiny5 snapping for every font. Stylix owns fontconfig.
      xdg.configFile."fontconfig/conf.d/50-yami-pixel.conf".enable = lib.mkForce false;
    };
}
