{ ... }:
{
  flake.modules.homeManager.ai-mcp =
{
  config,
  lib,
  pkgs,
  customPkgs,
  inputs,
  privateConfig ? { },
  ...
}:
{
  # The vault `zn mcp` serves. A host without the desktop app has no "vault
  # the app has open" to fall back on, so it is always set explicitly.
  options.custom.notesVault = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Notes";
    description = "Notes vault exposed to AI tools through the ZenNotes MCP.";
  };

  config.programs.mcp-config = {
    enable = true;

    # Core MCPs (always active, low overhead)
    mcpNixos.enable = true;

    # The notes vault is every tool's second brain, so it is on everywhere.
    # Each tool's process runs as its own user, so file permissions on the
    # vault still apply (Hermes's agents can write only to Hermes/).
    zennotes = {
      enable = true;
      cliPath = "${pkgs.writeShellScript "zn-notes" ''
        export ZENNOTES_VAULT="''${ZENNOTES_VAULT:-${config.custom.notesVault}}"
        exec ${customPkgs.zennotes-cli}/bin/zn "$@"
      ''}";
    };

    # Heavy MCPs (tools disabled globally, enabled via subagents)
    github = {
      enable = true;
      # Nothing exports GITHUB_TOKEN, so the client passes an empty token. Read the sops secret directly.
      package = pkgs.writeShellScriptBin "github-mcp-server" ''
        if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ -r /run/secrets/github-token ]; then
          GITHUB_PERSONAL_ACCESS_TOKEN="$(< /run/secrets/github-token)"
          export GITHUB_PERSONAL_ACCESS_TOKEN
        fi
        exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio "$@"
      '';
    };

    playwright = {
      enable = true;
      browser = "chromium";
      browserPath = "${pkgs.chromium}/bin/chromium";
      userDataDir = "${config.home.homeDirectory}/.config/playwright-chromium-profile";
    };

    # Second Playwright server for sandbox-only work (doc screenshots, demos).
    # It keeps the profile in memory, so it holds no logins and cannot clash
    # with the persistent profile's single-writer lock. Origin allow-lists are
    # not set: the Playwright MCP docs say they are not a security boundary.
    extraMcpServers.playwright-sandbox = {
      command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
      args = [
        "--browser" "chromium"
        "--executable-path" "${pkgs.chromium}/bin/chromium"
        "--isolated"
        "--viewport-size" "1920x1080"
        # Loads window.__ann (boxes, arrows, blur) for the screenshot-annotate skill.
        "--init-script" "${inputs.ai-tooling}/skills/screenshot-annotate/annotate.js"
      ];
    };

    # Optional MCPs (disabled by default)
    supermercados = {
      enable = false;
      autostart = false;
    };
  };

  # Work secrets for the Jira/Confluence/Tempo/JSM/Trello MCPs, sourced by
  # nushell (cli/nushell.nix). Generated from the private repo's secretEnv so
  # new instances/secrets appear here without hand-editing. Prefix filter keeps
  # inference keys (ANTHROPIC_API_KEY etc.) out of every shell: exporting those
  # would flip Claude Code from login auth to API-key billing.
  #
  # A home.file (not an activation script) so the file is part of the
  # generation: nushell's `source` needs it at parse time, and a half-run
  # activation used to leave it missing. Content is only secret *paths*, read
  # at shell start, so a store symlink is safe.
  config.home.file.".config/nushell/mcp-env.nu" =
    let
      mcpPrefixes = [ "WORK_" "JIRA_" "CONFLUENCE_" "JSM_" "TRELLO_" "TEMPO_" ];
      isMcp = name: lib.any (p: lib.hasPrefix p name) mcpPrefixes;
      secretEnv = lib.filterAttrs (n: _: isMcp n) (privateConfig.workSecretEnv or { });
    in
    {
      force = true; # replace the old activation-written regular file
      text =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (n: path: ''
            if ("${path}" | path exists) { $env.${n} = (open ${path} | str trim) }'') secretEnv
        )
        + "\n";
    };
};
}
