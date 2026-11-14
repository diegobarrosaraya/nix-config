# Module injected into nix-on-droid's initial bootstrap config. See bootstrap.nix.
{ keys, sshdConfig }:
{ pkgs, lib, ... }:
{
  environment.packages = [ pkgs.openssh ];
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "hm-backup";
    config = { pkgs, lib, ... }: {
      home.stateVersion = "24.05";
      home.file.".ssh/authorized_keys".text = (lib.concatStringsSep "\n" keys) + "\n";
      home.file.".ssh/sshd_config".source = sshdConfig;
      home.packages = [
        (pkgs.writeShellScriptBin "phone-sshd" ''
          set -e
          mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
          [ -f "$HOME/.ssh/ssh_host_ed25519_key" ] ||
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$HOME/.ssh/ssh_host_ed25519_key" -N ""
          exec ${pkgs.openssh}/bin/sshd -D -e -p "''${SSHD_PORT:-8022}" -f "$HOME/.ssh/sshd_config"
        '')
      ];
    };
  };
}
