{
  description = "My personal nix config";
  inputs = {

    hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    impermanence.url = "github:nix-community/impermanence";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";

    vital-presets = {
      url = "github:Miserlou/VitalPresets";
      flake = false;
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:guibou/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    pretty-mermaid-skills = {
      url = "github:imxv/Pretty-mermaid-skills";
      flake = false;
    };

    impeccable = {
      url = "github:pbakaus/impeccable";
      flake = false;
    };

    # Claude Code plugins for the Hermes-driven coding agents. Loaded with
    # --plugin-dir from the store (see ai/hermes-agent.nix), so no runtime install.
    # superpowers is pinned to the official marketplace's sha.
    superpowers = {
      url = "github:obra/superpowers/bb92a77741419a4ab5f06e711a283343f1ada0c3";
      flake = false;
    };
    ponytail = {
      url = "github:DietrichGebert/ponytail/2961b52fc1fe6a5a87c7a959a79512e5c2f3ffe5";
      flake = false;
    };

    # Second nixpkgs, used only for claude-agent-acp so the main pin stays put.
    nixpkgs-acp.url = "github:nixos/nixpkgs/nixos-unstable";

    ai-tooling = {
      url = "github:diegobarrosaraya/nix-ai-tooling";
    };

    private-config = {

      url = "git+ssh://git@github.com/diegobarrosaraya/nix-private-config.git";
      flake = true;
    };

    # Licensed assets (Font Awesome Pro icons), not for the public repo.
    private-assets = {
      url = "git+ssh://git@github.com/diegobarrosaraya/private-assets.git";
      flake = false;
    };

    # zennotes-server lives here now. No flake, but its default.nix takes pkgs.
    znserver = {
      url = "github:ZenNotes/znserver";
      flake = false;
    };

    ekphos = {
      url = "github:hanebox/ekphos";
      flake = false;
    };

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent.url = "github:NousResearch/hermes-agent";

    teams-calls-fetcher = {
      url = "github:diegobarrosaraya/teams-calls-fetcher";
    };

  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./parts)
      ];
    };
}
