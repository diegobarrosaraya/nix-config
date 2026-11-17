{ inputs, ... }:
{
  flake.modules.homeManager.desktop-common-zen =
    { pkgs, lib, ... }:
    let
      extension = shortId: guid: {
        name = guid;
        value = {
          install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
          installation_mode = "normal_installed";
        };
      };
      # The flake names the stable release "beta". binaryName is a let-binding,
      # so override cannot rename the command, desktop file, or window class.
      zenFlake = inputs.zen-browser;
      zenPackage = builtins.readFile "${zenFlake}/package.nix";
      patchedPackage = lib.replaceStrings
        [ ''binaryName = "zen-''${name}";'' ]
        [ ''binaryName = "zen";'' ]
        zenPackage;
      policies = {
        DisableTelemetry = true;
        DisableAppUpdate = true;
        DisablePocket = true;

        ExtensionSettings = builtins.listToAttrs [
          (extension "ublock-origin" "uBlock0@raymondhill.net")
        ];

        SearchEngines = {
          Default = "ddg";
          Add = [
            {
              Name = "nixpkgs packages";
              URLTemplate = "https://search.nixos.org/packages?query={searchTerms}";
              IconURL = "https://wiki.nixos.org/favicon.ico";
              Alias = "@np";
            }
            {
              Name = "NixOS options";
              URLTemplate = "https://search.nixos.org/options?query={searchTerms}";
              IconURL = "https://wiki.nixos.org/favicon.ico";
              Alias = "@no";
            }
            {
              Name = "NixOS Wiki";
              URLTemplate = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
              IconURL = "https://wiki.nixos.org/favicon.ico";
              Alias = "@nw";
            }
            {
              Name = "noogle";
              URLTemplate = "https://noogle.dev/q?term={searchTerms}";
              IconURL = "https://noogle.dev/favicon.ico";
              Alias = "@ng";
            }
          ];
        };
      };
    in
    assert patchedPackage != zenPackage;
    {
      # homeModules.beta is the stable release. Twilight is the pre-release.
      imports = [ inputs.zen-browser.homeModules.beta ];

      home.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

      programs.zen-browser = {
        enable = true;
        setAsDefaultBrowser = true;
        inherit policies;
        # name stays "beta" so the icon name stays zen-browser. The tarball is stable.
        unwrappedPackage = pkgs.callPackage (builtins.toFile "zen-package.nix" patchedPackage) {
          name = "beta";
          applicationName = "Zen Browser";
          variant =
            (builtins.fromJSON (builtins.readFile "${zenFlake}/sources.json")).variants.beta.${pkgs.stdenv.hostPlatform.system};
          inherit policies;
        };

        profiles.default.settings = {
          "browser.startup.homepage" = "https://home.minerales.network/";
          "browser.startup.page" = 1;
          "browser.newtabpage.url" = "https://home.minerales.network/";

          "media.peerconnection.video.min_bitrate" = 512;
          "media.peerconnection.video.start_bitrate" = 1500;
          "media.peerconnection.video.max_bitrate" = 8000;

          "media.ffmpeg.vaapi.enabled" = true;
        };
      };

      stylix.targets.zen-browser.profileNames = [ "default" ];
    };
}
