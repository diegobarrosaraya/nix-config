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
      ekphos = pkgs.callPackage ../pkgs/ekphos { src = inputs.ekphos; };
      teams-calls-fetcher = inputs.teams-calls-fetcher.packages.${system}.default;
    }
  );
}
