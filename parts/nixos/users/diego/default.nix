{ ... }:
{
  flake.modules.nixos.users-diego = {
  config,
  pkgs,
  lib,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{

  environment.shells = with pkgs; [ nushell bash fish ];

  users.mutableUsers = false;
  users.groups.diego = {};
  users.users = {
    diego = {
      isNormalUser = true;
      group = "diego";
      packages = [ pkgs.home-manager ];
      extraGroups = [
        "wheel"
        "audio"
        "storage"
        "input"
        "video"
      ]
        ++ ifTheyExist [
          "media"
          "syncthing"
          "network"
          "networkmanager"
          "i2c"
          "docker"
          "git"
          "libvirtd"
          "adbusers"
        ];
      shell = pkgs.nushell;
      description = "Diego Barros";

      hashedPasswordFile = "/run/secrets-for-users/diego-password";
      openssh.authorizedKeys.keys = (import ../../../_ssh-keys.nix).authorized;
    };
  };
};
}
