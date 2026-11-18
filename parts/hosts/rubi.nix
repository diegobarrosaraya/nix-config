{ config, inputs, ... }:
{
  flake.nixosConfigurations.rubi = inputs.nixpkgs.lib.nixosSystem {
    pkgs = config.flake.legacyPackages.x86_64-linux;
    modules = with config.flake.modules.nixos; [
      rubi
      openrgb
    ];
    specialArgs = {
      inherit inputs;
      self = inputs.self;
      outputs = inputs.self;
      customPkgs = config.flake.packages.x86_64-linux;
      desktop = "sway";
      theme = null;
    };
  };
}
