{ inputs, ... }:
{

  additions = final: _prev: import ../../pkgs { pkgs = final; };

  nixgl = inputs.nixgl.overlay;

  pythonFixes = _final: prev: {
    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_self: super:
        let
          tsLangs = [
            "python-tree-sitter-c"
            "python-tree-sitter-c-sharp"
            "python-tree-sitter-cpp"
            "python-tree-sitter-elixir"
            "python-tree-sitter-go"
            "python-tree-sitter-java"
            "python-tree-sitter-javascript"
            "python-tree-sitter-julia"
            "python-tree-sitter-kotlin"
            "python-tree-sitter-lua"
            "python-tree-sitter-objc"
            "python-tree-sitter-php"
            "python-tree-sitter-powershell"
            "python-tree-sitter-python"
            "python-tree-sitter-ruby"
            "python-tree-sitter-rust"
            "python-tree-sitter-scala"
            "python-tree-sitter-swift"
            "python-tree-sitter-typescript"
            "python-tree-sitter-verilog"
            "python-tree-sitter-zig"
          ];
          skipMeta = name:
            if super ? ${name}
            then { ${name} = super.${name}.overridePythonAttrs (_old: { dontCheckPythonMetadata = true; }); }
            else { };
        in
        builtins.foldl' (acc: name: acc // skipMeta name) { } tsLangs
      )
    ];
  };

  modifications = final: prev: {
    dummy = prev.hello;

    # patchelf 0.19 drops PT_PHDR from the insync launcher, so it segfaults in ld.so, while 0.18
    # can't patch the bundled libs (no .hash section). Patch everything with 0.19, then redo just
    # the launcher from its original copy with 0.18. The .deb's Qt *.debug files break patchelf too.
    # insync-pkg is let-bound inside the package, so reach it through its stdenvNoCC argument.
    # shortcut: launcher pinned to patchelfUnstable (0.18), drop once nixpkgs patchelf keeps PT_PHDR.
    insync = prev.insync.override {
      stdenvNoCC = prev.stdenvNoCC // {
        mkDerivation = args: prev.stdenvNoCC.mkDerivation (args // {
          postInstall = (args.postInstall or "") + ''
            find $out -name '*.debug' -delete
            cp $out/lib/insync/insync $NIX_BUILD_TOP/insync-orig
          '';
          # Appended after autoPatchelfPostFixup, so it runs once autoPatchelf is done.
          preFixup = (args.preFixup or "") + ''
            repatchInsyncLauncher() {
              local bin=$out/lib/insync/insync
              local interp rpath
              interp=$(patchelf --print-interpreter $bin)
              rpath=$(patchelf --print-rpath $bin)
              cp $NIX_BUILD_TOP/insync-orig $bin
              ${final.patchelfUnstable}/bin/patchelf --set-interpreter "$interp" --set-rpath "$rpath" $bin
            }
            postFixupHooks+=(repatchInsyncLauncher)
          '';
        });
      };
    };

    xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (_oldAttrs: {
      version = "0.8.4";
      src = final.fetchFromGitHub {
        owner = "emersion";
        repo = "xdg-desktop-portal-wlr";
        rev = "v0.8.4";
        sha256 = "sha256-8Ohgkz13FcG8ddjjgreXkvFD2Q+zUDZnAM4Oh+C9P/s=";
      };
    });

    ncmpcpp = prev.ncmpcpp.overrideAttrs (oldAttrs: rec {
      visualizerSupport = true;
      clockSupport = true;
    });

    homepage-dashboard = prev.homepage-dashboard.overrideAttrs (oldAttrs: {
      version = "1.13.2-dev-unstable";
      src = final.fetchFromGitHub {
        owner = "gethomepage";
        repo = "homepage";
        rev = "84c7e5126977ca2f58ccf3caa46c88eaf670c5dd";
        hash = "sha256-qR81EMAJL2tL9BshzQuEOV9fFCHidXRHJM4gPFGy2Vo=";
      };
      pnpmDeps = final.fetchPnpmDeps {
        pname = "homepage-dashboard";
        version = "1.13.2-dev-unstable";
        src = final.fetchFromGitHub {
          owner = "gethomepage";
          repo = "homepage";
          rev = "84c7e5126977ca2f58ccf3caa46c88eaf670c5dd";
          hash = "sha256-qR81EMAJL2tL9BshzQuEOV9fFCHidXRHJM4gPFGy2Vo=";
        };
        pnpm = final.pnpm_10;
        fetcherVersion = 3;
        hash = "sha256-zWvSivqwAMO6EFhYgXUyxJQsJTwvhmExu6t+EIwCFqs=";
      };
    });

    music-assistant = prev.music-assistant.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace music_assistant/providers/apple_music/constants.py \
          --replace '"/usr/local/bin/widevine_cdm"' '"/var/lib/music-assistant/widevine_cdm"'
      '';
    });

    python3Packages = if final.stdenv.hostPlatform.system != "i686-linux" then
      prev.python3Packages.override {
        overrides = self: super: {
          python-miio = super.python-miio.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./python-miio-click-8-compat.patch ];
          });

          pymp4 = self.callPackage ../../pkgs/pymp4 { };

          pywidevine = self.callPackage ../../pkgs/pywidevine {
            inherit (final) shaka-packager;
          };

          construct = self.callPackage ../../pkgs/construct { };

          authcaptureproxy = super.authcaptureproxy.overridePythonAttrs (_old: {
            doCheck = false;
          });
        };
      }
    else
      prev.python3Packages;

  };
}
