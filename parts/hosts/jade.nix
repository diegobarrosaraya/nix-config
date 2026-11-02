{ config, inputs, ... }:
{
  flake.nixOnDroidConfigurations.jade = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = config.flake.legacyPackages.aarch64-linux;
    modules = [ ../../hosts/jade/nix-on-droid.nix ];
    home-manager-path = inputs.home-manager.outPath;
    extraSpecialArgs = {
      inherit inputs;
      homeModules = config.flake.modules.homeManager;
      customPkgs = config.flake.packages.aarch64-linux;
    };
  };
}
