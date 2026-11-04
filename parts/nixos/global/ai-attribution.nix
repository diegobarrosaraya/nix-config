{ ... }:
{
  # In personal repos, commits credit Azogue bot, never an AI tool. Work repos
  # keep each tool's defaults. System-wide, so it covers diego and the hermes
  # user. Personal means under ~/Projects/Personal or with a remote on Diego's
  # own GitHub owners, so no work path or customer is named here.
  flake.modules.nixos.global-ai-attribution =
{ config, lib, pkgs, ... }:
let
  hook = import ../../../pkgs/ai-attribution-hook.nix { inherit pkgs; };

  # Only this file carries the hook, so nothing depends on section order.
  include = pkgs.writeText "ai-attribution.gitconfig" (lib.generators.toGitINI ({
    # A config-defined hook runs before the repo's own commit-msg hook, so
    # repos with husky or pre-commit keep theirs (core.hooksPath would not).
    hook.ai-attribution = {
      event = "commit-msg";
      command = "${hook.script}/bin/ai-attribution-commit-msg";
    };
  } // config.custom.aiAttribution.gitConfig));

  remotes = lib.concatMap (owner: [
    "https://github.com/${owner}/**"
    "git@github.com:${owner}/**"
    "ssh://git@github.com/${owner}/**"
  ]) [ "diegobarrosaraya" "DiegoBarrosA" ];
in
{
  options.custom.aiAttribution.gitConfig = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Extra git config applied only in personal repos, next to the hook.";
  };

  config.programs.git = {
    enable = true;
    config.includeIf = lib.genAttrs (
      [ "gitdir:~/Projects/Personal/" ] ++ map (r: "hasconfig:remote.*.url:${r}") remotes
    ) (_: { path = "${include}"; });
  };
};
}
