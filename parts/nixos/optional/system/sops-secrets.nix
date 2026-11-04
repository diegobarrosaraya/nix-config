{ ... }:
{
  flake.modules.nixos.system-sops-secrets = {
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
    useSystemdActivation = true;

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

    secrets."cloudflare-dns-token" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."cloudflare-zone-token" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."luks-passphrase" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."jellyfin-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    secrets."prowlarr-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    secrets."sonarr-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    secrets."radarr-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    secrets."lidarr-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    secrets."bazarr-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."nextauth-secret" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    secrets."syncthing-api-key" = {
      owner = "diego";
      group = "users";
      mode = "0640";
    };

    secrets."syncthing-password" = {
      owner = "root";
      group = "diego";
      mode = "0640";
    };

    secrets."vaultwarden-admin-token" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."aria2-rpc-secret" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."tdarr-server-env" = {
      owner = "media";
      group = "media";
      mode = "0400";
    };

    secrets."tdarr-node-env" = {
      owner = "media";
      group = "media";
      mode = "0400";
    };

    secrets."resend-api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."restic-local-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."restic-remote-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."r2-access-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."r2-secret-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."r2-account-id" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."protondrive-username" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # rclone-obscured (`rclone obscure '<password>'`), not plaintext.
    secrets."protondrive-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # rclone-obscured TOTP secret (`rclone obscure '<base32-secret>'`); leave
    # the entry blank in secrets.yaml if the account has no 2FA.
    secrets."protondrive-otp-secret" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    templates."rclone-proton.conf" = {
      content = ''
        [proton]
        type = protondrive
        username = ${config.sops.placeholder."protondrive-username"}
        password = ${config.sops.placeholder."protondrive-password"}
        otp_secret_key = ${config.sops.placeholder."protondrive-otp-secret"}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };

    templates."restic-proton.env" = {
      content = ''
        RESTIC_EXTRA_PASSWORD_PROTON=${config.sops.placeholder."restic-remote-password"}
        RCLONE_CONFIG_PROTON=${config.sops.templates."rclone-proton.conf".path}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."hermes-dashboard-password" = { };
    secrets."hermes-dashboard-secret" = { };
    secrets."hermes-nvidia-api-key" = { };
    # Same value as rubi's opencode-api-key (Zen and Go share one key).
    # Group hermes can read it so the `opencode` wrapper in hermes-agent.nix can export it.
    secrets."opencode-api-key" = {
      group = "hermes";
      mode = "0440";
    };
    secrets."telegram-user-id" = { };
    secrets."telegram-bot-token" = { };
    secrets."hermes-github-token" = { };
    # Personal Claude setup token (`claude setup-token`). diego runs the
    # launcher, the hermes group runs the ACP wrapper.
    secrets."claude-token-personal" = {
      owner = "diego";
      group = "hermes";
      mode = "0440";
    };

    templates."hermes.env" = {
      content = ''
        HERMES_DASHBOARD_BASIC_AUTH_USERNAME=diego
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes-dashboard-password"}
        HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes-dashboard-secret"}
        NVIDIA_API_KEY=${config.sops.placeholder."hermes-nvidia-api-key"}
        OPENCODE_ZEN_API_KEY=${config.sops.placeholder."opencode-api-key"}
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."telegram-bot-token"}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."telegram-user-id"}
        GH_TOKEN=${config.sops.placeholder."hermes-github-token"}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
      # Hermes reads .env only at process start.
      restartUnits = [ "hermes-agent.service" "hermes-backend.service" ];
    };

    # Reviewer and security run in a routed profile home, where Hermes drops keys inherited
    # from hermes.env. Only the provider key they use is copied into their profile .env.
    templates."hermes-nvidia.env" = {
      content = ''
        NVIDIA_API_KEY=${config.sops.placeholder."hermes-nvidia-api-key"}
      '';
      owner = "hermes";
      group = "hermes";
      mode = "0400";
      restartUnits = [ "hermes-profiles.service" ];
    };

    templates."restic.env" = {
      content = ''
        RESTIC_LOCAL_PASSWORD=${config.sops.placeholder."restic-local-password"}
        RESTIC_REMOTE_PASSWORD=${config.sops.placeholder."restic-remote-password"}
        RESTIC_S3_ENDPOINT=https://${config.sops.placeholder."r2-account-id"}.r2.cloudflarestorage.com
        AWS_ACCESS_KEY_ID=${config.sops.placeholder."r2-access-key"}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."r2-secret-key"}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  systemd.services."sops-install-secrets" = {
    unitConfig.ConditionFileNotEmpty = lib.mkForce "";
    onFailure = lib.mkForce [ ];
  };

  users.users.acme = {
    isSystemUser = true;
    group = "acme";
  };
  users.groups.acme = { };
};
}
