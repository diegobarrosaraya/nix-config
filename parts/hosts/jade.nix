{ config, inputs, ... }:
let
  pkgs = config.flake.legacyPackages.aarch64-linux;
  extraSpecialArgs = {
    inherit inputs;
    homeModules = config.flake.modules.homeManager;
    customPkgs = config.flake.packages.aarch64-linux;
  };
  nodModules = import "${inputs.nix-on-droid}/modules/module-list.nix" {
    inherit pkgs;
    home-manager-path = inputs.home-manager.outPath;
    isFlake = true;
    targetSystem = pkgs.stdenv.hostPlatform.system;
  };
  # Same evaluation as nix-on-droid's nixOnDroidConfiguration, except that the
  # activation fix comes last: build.activation merges last-wins, and the stock
  # installPackages (in nodModules) would otherwise override it.
  evaluated = pkgs.lib.evalModules {
    modules = [
      ../../hosts/jade/activation-fix.nix
      { imports = [ ../../hosts/jade/nix-on-droid.nix ]; }
    ] ++ nodModules;
    specialArgs = extraSpecialArgs;
  };
in
{
  flake.nixOnDroidConfigurations.jade = {
    inherit (evaluated.config.build) activationPackage;
    inherit (evaluated) config options;
    inherit pkgs;
  };
}
