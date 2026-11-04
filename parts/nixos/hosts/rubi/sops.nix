{ ... }:
{
  flake.modules.nixos.rubi-sops = {
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}:

with lib;

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = "${self}/hosts/${config.networking.hostName}/secrets.yaml";
    defaultSopsFormat = "yaml";
    age.keyFile = "/nix/persist/var/lib/sops-nix/key.txt";
    age.generateKey = false;

    secrets."diego-password" = {
      neededForUsers = true;
      owner = "root";
      group = "root";
      mode = "0600";
    };

    secrets."tailscale-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."luks-passphrase" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."github-token" = {
      owner = "diego";
      group = "users";
      mode = "0400";
      sopsFile = inputs.private-config.secretFiles.githubToken;
      key = "github_token";
    };

    secrets."couchdb-admin-user" = {
      owner = "diego";
      group = "users";
      mode = "0400";
    };

    # Copy of cobalto's LiteLLM key, for opencode and pi on rubi.
    secrets."litellm-master-key" = {
      owner = "diego";
      group = "users";
      mode = "0400";
    };

    secrets."couchdb-admin-password" = {
      owner = "diego";
      group = "users";
      mode = "0400";
    };

    secrets."obsidian-livesync-passphrase" = {
      owner = "diego";
      group = "users";
      mode = "0400";
    };

    secrets."groq-api-key" = {
      owner = "diego";
      group = "users";
      mode = "0400";
    };
  };

  sops.templates."nix-github-access-token" = {
    content = "access-tokens = github.com=${config.sops.placeholder."github-token"}";
    path = "/etc/nix/github-access-token.conf";
    owner = "root";
    group = "root";
    mode = "0444";
  };
};
}
