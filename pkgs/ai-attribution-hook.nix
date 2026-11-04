# commit-msg hook: no AI is credited in commits, Azogue bot is. Imported by
# parts/nixos/global/ai-attribution.nix (git and Claude Code config) and
# parts/checks.nix (the test); it lives outside parts/ because import-tree
# would load every .nix there as a module.
{ pkgs }:
rec {
  trailer = "Co-Authored-By: Azogue bot <azogue@minerales.network>";

  script = pkgs.writeShellApplication {
    name = "ai-attribution-commit-msg";
    runtimeInputs = with pkgs; [ git gnugrep diffutils coreutils ];
    text = ''
      msg="$1"
      ai='claude|anthropic|openai|chatgpt|gpt-?[0-9]|codex|copilot|gemini|cursor|opencode|hermes|nousresearch|aider|devin|kimi|deepseek|qwen|llama|mistral|grok'
      # Drop trailers and footers that credit an AI: "<x>-by:" lines, Claude
      # session links and "Generated with" footers. Human trailers stay.
      grep -viE "^[[:space:]]*([a-z-]+-by|claude-session):.*($ai)|^[[:space:]]*(🤖[[:space:]]*)?generated (with|by) .*($ai)" "$msg" > "$msg.tmp" || true
      stripped=0
      cmp -s "$msg" "$msg.tmp" || stripped=1
      mv "$msg.tmp" "$msg"

      # An agent made this commit if it carried AI credit or runs in an agent
      # shell: Claude Code sets CLAUDECODE, pi sets PI_CODING_AGENT.
      # shortcut: OPENCODE is not confirmed in the opencode binary; check it
      # with `env` from an opencode shell if its commits lack the trailer.
      if [ "$stripped" = 1 ] || [ -n "''${CLAUDECODE:-}''${PI_CODING_AGENT:-}''${OPENCODE:-}" ]; then
        # Hermes commits as Azogue bot already, so it needs no co-author.
        case "$(git var GIT_AUTHOR_IDENT)" in *"<azogue@minerales.network>"*) exit 0 ;; esac
        git interpret-trailers --in-place --if-exists addIfDifferent --trailer ${pkgs.lib.escapeShellArg trailer} "$msg"
      fi
    '';
  };
}
