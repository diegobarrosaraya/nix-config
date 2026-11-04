# commit-msg hook: a commit that says it bumps or updates a lock may contain
# only flake.lock files. `git add flake.lock && git commit` also commits
# whatever another session had staged (three times in nix-config on
# 2026-11-04). Imported by parts/nixos/global/ai-attribution.nix; tested by
# checks.ai-attribution-scope. Outside parts/ because import-tree loads .nix there.
{ pkgs }:
pkgs.writeShellApplication {
  name = "lock-bump-guard";
  runtimeInputs = with pkgs; [ git gnugrep coreutils ];
  text = ''
    case "$(head -n1 "$1")" in
      "chore: bump "* | "chore: update "*) ;;
      *) exit 0 ;;
    esac
    # With `git commit -- <path>` git commits from a temporary index, which
    # is what --cached reads here, so other staged files do not show up.
    others=$(git diff --cached --name-only | grep -v -x -e flake.lock -e '.*/flake.lock' || true)
    [ -z "$others" ] && exit 0
    {
      echo "lock-bump-guard: this commit bumps a lock, but other files are staged:"
      while IFS= read -r f; do echo "  $f"; done <<< "$others"
      echo "Commit only the lock: git commit -m \"...\" -- flake.lock"
    } >&2
    exit 1
  '';
}
