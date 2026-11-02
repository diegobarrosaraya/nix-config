{ ... }:
{
  flake.modules.nixos.global-openssh = { outputs, lib, config, ... }:
let
  hosts = lib.filterAttrs (name: _: builtins.pathExists ../../../hosts/${name}/ssh_host_ed25519_key.pub) outputs.nixosConfigurations;
  hostname = config.networking.hostName;
  prefix = "";
  pubKey = host: builtins.toPath (../../../hosts/${host}/ssh_host_ed25519_key.pub);

  authorizedKeys = (import ../../_ssh-keys.nix).authorized;
in {
  services.openssh = {
    enable = true;

    settings.PasswordAuthentication = false;
    settings.PubkeyAuthentication = true;
    settings.PermitRootLogin = lib.mkForce "prohibit-password";

    extraConfig = ''
      StreamLocalBindUnlink yes
    '';

    settings.GatewayPorts = "clientspecified";

    hostKeys = [{
      path = "${prefix}/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  programs.ssh = {

    knownHosts = {};
  };

  security.pam.sshAgentAuth.enable = true;
};
}
