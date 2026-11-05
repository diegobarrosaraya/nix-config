# Replaces the installPackages step of nix-on-droid's activation. parts/hosts/jade.nix
# appends this module after nix-on-droid's own modules, because build.activation
# merges last-wins and the stock step would otherwise win.
#
# The stock step fails with nix 2.31: `nix profile list` no longer matches its
# grep/cut, so xargs runs `nix profile remove` with no arguments, and the nix-env
# fallback fails on this device. nix-on-droid-path is installed with the new CLI.
{ config, ... }:
{
  build.activation.installPackages = ''
    export NIX_PROFILE=${config.user.home}/.nix-profile
    for name in nix-on-droid-path openssh; do
      $DRY_RUN_CMD ${config.nix.package}/bin/nix profile remove "$name" 2>/dev/null || true
    done
    $DRY_RUN_CMD ${config.nix.package}/bin/nix profile install ${config.environment.path}
  '';
}
