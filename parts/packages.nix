{ config, inputs, lib, ... }:
{
  flake.packages = lib.genAttrs config.systems (
    system:
    let
      pkgs = config.flake.legacyPackages.${system};
      privatePackages = inputs.private-config.packages.${system} or { };
    in
    import ../pkgs { inherit pkgs lib privatePackages; }
    // {
      coderabbit-cli = inputs.llm-agents.packages.${system}.coderabbit-cli;
      zennotes-server = import inputs.znserver { inherit pkgs; };
      # The `zn` CLI (and `zn mcp`) from the desktop app. The app writes its
      # own ~/.config/ZenNotes/cli/zen, which breaks once its store paths go.
      # shortcut: same wrapper as nixpkgs' installCli, without rebuilding the
      # app; switch to zennotes-desktop.override { installCli = true; } once
      # that build is in the binary cache.
      zennotes-cli = pkgs.writeShellScriptBin "zn" ''
        export ELECTRON_RUN_AS_NODE=1
        exec ${pkgs.electron_44}/libexec/electron/electron \
          ${pkgs.zennotes-desktop}/lib/node_modules/zennotes-monorepo/apps/desktop/out/main/cli.js "$@"
      '';
      ekphos = pkgs.callPackage ../pkgs/ekphos { src = inputs.ekphos; };
      pretty-mermaid-skill = pkgs.callPackage ../pkgs/pretty-mermaid-skill { src = inputs.pretty-mermaid-skills; };
      teams-calls-fetcher = inputs.teams-calls-fetcher.packages.${system}.default;
    }
  );
}
