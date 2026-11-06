{ ... }:
{
  flake.modules.homeManager.ai-ai-tools =
{
  config,
  lib,
  pkgs,
  customPkgs,
  inputs,
  ...
}:
{
  # Claude Code
  programs.claude-code-config.enable = true;

  # mermaid-cli (mmdc) renders diagrams to PNG for guides, next to the pretty-mermaid skill.
  home.packages = [ pkgs.pi-coding-agent pkgs.mermaid-cli ];
  # pi reads user MCP servers from here (standard format); only the notes vault.
  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    mcpServers = { inherit (config.programs.mcp-config.standardFormat.mcpServers) notes; };
  };

  programs.claude-code-config = {
    # Impeccable agents
    extraAgentSources = [ "${inputs.impeccable}/.claude/agents" ];

    enabledPlugins = {
      "superpowers@claude-plugins-official" = true;
      "ponytail@ponytail" = true;
    };

    extraKnownMarketplaces = {
      ponytail = {
        source = {
          source = "github";
          repo = "DietrichGebert/ponytail";
        };
      };
    };
  };

  # Extra profiles: ~/.config/claude-code-<name>, launched via claude-<name>.
  # They do not inherit the default profile's MCP servers.
  programs.claude-code-config.profiles = {
    # Plugins are per profile too, so repeat the default set here.
    personal = {
      inherit (config.programs.claude-code-config) enabledPlugins extraKnownMarketplaces;
      # Only the notes vault; the profile keeps the rest of its MCP set empty.
      mcpServers = { inherit (config.programs.mcp-config.standardFormat.mcpServers) notes; };
    };
    sr = {
      # Same MCP set as the default profile (mirrors the module's own merge).
      mcpServers =
        config.programs.mcp-config.standardFormat.mcpServers
        // config.programs.claude-code-config.extraMcpServers;
      
      # Plugins are per profile too, so repeat the default set here.
      inherit (config.programs.claude-code-config) enabledPlugins extraKnownMarketplaces;
    };
  };

  # Cursor
  programs.cursor-config.enable = true;

  # Antigravity
  programs.antigravity-config.enable = true;

  # Skills
  programs.ai-skills = {
    enable = true;

    extraSkillSources = [
      "${inputs.impeccable}/.claude/skills"
      "${customPkgs.pretty-mermaid-skill}"
    ];
  };

  # System prompt
  programs.ai-system-prompt.enable = true;
};
}
