{ config, ... }:
{
  flake.modules.nixos.global = { inputs, outputs, customPkgs ? {}, desktop ? null, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ] ++ (with config.flake.modules.nixos; [ global-openssh global-locale global-ai-attribution ]);
  networking.domain = "mineral.network";

  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = {
    inherit inputs outputs customPkgs desktop;
    privateConfig = inputs.private-config or { };
    isNixOnDroid = false;
  };
  environment = {
    loginShellInit = ''
      [ -d "$HOME/.nix-profile" ] || /nix/var/nix/profiles/per-user/$USER/home-manager/activate &> /dev/null
    '';

  };

  programs.fuse.userAllowOther = true;
  hardware.enableRedistributableFirmware = true;
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];
};
}
