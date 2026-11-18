{ config, inputs, ... }:
let
  # Same module set, in the same order, as the old `builtins.attrValues homeModules`
  # (modules/home-manager plus the ai-tooling modules, sorted by attribute name).
  commonModules = with config.flake.modules.homeManager; [
    inputs.ai-tooling.homeManagerModules.ai-skills
    inputs.ai-tooling.homeManagerModules.ai-system-prompt
    inputs.ai-tooling.homeManagerModules.agent-accounts
    inputs.ai-tooling.homeManagerModules.antigravity-config
    bar
    inputs.ai-tooling.homeManagerModules.claude-code-config
    inputs.ai-tooling.homeManagerModules.claude-desktop-config
    colors
    inputs.ai-tooling.homeManagerModules.cursor-config
    inputs.ai-tooling.homeManagerModules.jcode-config
    inputs.ai-tooling.homeManagerModules.mcp-config
    monitors
    inputs.ai-tooling.homeManagerModules.opencode-config
  ]
  ++ [
    inputs.stylix.homeModules.stylix
    inputs.private-config.homeManagerModules.workMcpConfig
  ];

  mkHome =
    {
      entrypoint,
      extraModules ? [ ],
      desktop ? null,
      theme ? null,
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = config.flake.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        inherit inputs;
        customPkgs = config.flake.packages.x86_64-linux;
        privateConfig = inputs.private-config or { };
        inherit desktop theme;
        isNixOnDroid = false;
      };
      modules = commonModules ++ [ entrypoint ] ++ extraModules;
    };
in
{
  flake.homeConfigurations = {
    "diego@cobalto" = mkHome {
      entrypoint = config.flake.modules.homeManager.cobalto;
      theme = {
        scheme = "material-darker";
        mode = "dark";
      };
    };
    "diego@rubi" = mkHome {
      entrypoint = config.flake.modules.homeManager.rubi;
      extraModules = [ inputs.private-config.homeManagerModules.workExtras ];
      desktop = "sway";
    };
  };
}
