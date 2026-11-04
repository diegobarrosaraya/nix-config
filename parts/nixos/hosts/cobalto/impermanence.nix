{ ... }:
{
  flake.modules.nixos.cobalto-impermanence = {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  boot.initrd.supportedFilesystems = [ "btrfs" ];

  environment.persistence."/nix/persist" = {
    hideMounts = true;
    directories = [

      "/etc/nixos"
      "/etc/ssh"
      "/var/log"
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/sops-nix"
      "/var/lib/bluetooth"
      "/var/lib/NetworkManager"
      "/var/lib/tailscale"

      "/var/lib/containers"

      "/var/lib/jellyfin"
      "/var/lib/cockpit"
      "/var/lib/hass"
      "/var/lib/miniflux"
      "/var/lib/postgresql"
      "/var/lib/private/music-assistant"

      "/var/lib/bitwarden_rs"
      "/var/lib/vaultwarden"
      "/var/lib/bazarr"
      "/var/lib/private/open-webui"
      "/var/lib/hermes"
      "/var/lib/pihole"
      # Without this the wildcard cert is destroyed on every boot and has to be
      # re-issued, which burns Let's Encrypt's duplicate-certificate quota.
      "/var/lib/acme"
      # postgres dumps, otherwise wiped on every boot and absent from any
      # backup taken before the next nightly dump runs. Needs explicit
      # ownership: impermanence would otherwise create it root:root and
      # pg_dumpall, which runs as postgres, cannot write there.
      {
        directory = "/var/backup/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "0700";
      }

      # servarr/nextcloud deliberately NOT persisted through impermanence: they
      # live directly on the /nix/storage disk. Binding them from /nix/persist
      # made /nix/storage ephemeral-backing, which forces neededForBoot=true and
      # therefore an initrd unlock - incompatible with unlocking that disk from a
      # keyfile after boot. Their prior contents were migrated off /nix/persist.

      {
        directory = "/home/diego";
        user = "diego";
        group = "users";
        mode = "0755";
      }
    ];

    files = [

      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"

      "/etc/machine-id"
    ];

    users.diego = {
      directories = [
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "nix-config"
        ".ssh"
        ".config"
        ".config/syncthing"
        ".syncthing"
        ".local"
        ".cache"

        "Projects"

        {
          directory = ".claude";
          mode = "0700";
        }
        {
          directory = ".codex";
          mode = "0700";
        }
        {
          directory = ".happy";
          mode = "0700";
        }

        {
          directory = "media";
          mode = "0755";
        }
      ];

      files = [ ];
    };
  };

  fileSystems."/nix/persist" = {
    device = "/dev/mapper/cobalto-root";
    fsType = "btrfs";
    options = [
      "subvol=persist"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/cobalto-root";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = lib.mkForce true;
  };

  # Deliberately NOT neededForBoot: this disk is unlocked in the real system
  # from a keyfile on root (see hardware-configuration.nix crypttab), so initrd
  # cannot mount it - and marking it boot-critical deadlocks the boot.
  fileSystems."/nix/storage" = {
    device = "/dev/mapper/cobalto-storage";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = lib.mkForce false;
  };

  boot.initrd.systemd.services.wipe-root = {
    description = "Wipe root subvolume and restore from blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "dev-mapper-cobalto\\x2droot.device" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "2min";
    };
    script = ''
      mkdir -p /tmp
      MNTPOINT=$(mktemp -d)
      (
        mount -t btrfs -o subvol=/ /dev/mapper/cobalto-root "$MNTPOINT"
        trap 'umount "$MNTPOINT"' EXIT

        echo "Creating needed directories for impermanence"
        mkdir -p "$MNTPOINT"/persist/var/{log,lib/{nixos,systemd}}
        mkdir -p "$MNTPOINT"/persist/etc/ssh

        if [ -e "$MNTPOINT/persist/dont-wipe" ]; then
          echo "Skipping wipe (dont-wipe flag found)"
        else
          echo "Cleaning root subvolume"
          btrfs subvolume delete -R "$MNTPOINT/root" || true

          if [ ! -e "$MNTPOINT/root" ]; then
            echo "Creating root subvolume"
            btrfs subvolume create "$MNTPOINT/root"
          fi

          if [ ! -e "$MNTPOINT/root-blank" ]; then
            echo "Creating blank root snapshot"
            btrfs subvolume snapshot -r "$MNTPOINT/root" "$MNTPOINT/root-blank"
          else
            echo "Restoring from blank snapshot"
            btrfs subvolume delete -R "$MNTPOINT/root" || true
            btrfs subvolume snapshot "$MNTPOINT/root-blank" "$MNTPOINT/root"
          fi
        fi

        chmod 755 "$MNTPOINT"/persist/etc/ssh || true
      )
    '';
  };

  systemd.tmpfiles.rules = [

    "d /run/secrets 0755 root root -"
    "d /run/containers 0755 root root -"
    "d /tmp/containers-diego 0755 diego users -"

    "d /nix/persist/var/lib/sops-nix 0700 root root -"

    "d /nix/persist/etc 0755 root root -"
    "d /nix/persist/etc/ssh 0755 root root -"
    "d /nix/persist/var 0755 root root -"
    "d /nix/persist/var/log 0755 root root -"
    "d /nix/persist/var/lib 0755 root root -"
    "d /nix/persist/home 0755 root root -"
    "d /nix/persist/home/diego 0755 diego users -"
    "d /nix/persist/nix 0755 root root -"
    "d /nix/persist/nix/storage 0755 root root -"

    "d /nix/persist/var/lib/hass 0700 hass hass -"

    "d /nix/persist/var/lib/miniflux 0750 miniflux miniflux -"
    "d /nix/persist/var/lib/postgresql 0750 postgres postgres -"

    "d /nix/storage/servarr 0755 root root -"
    "d /nix/storage/servarr/prowlarr 0755 root root -"
    "d /nix/storage/servarr/sonarr 0755 root root -"
    "d /nix/storage/servarr/radarr 0755 root root -"
    "d /nix/storage/servarr/lidarr 0755 root root -"
    "d /nix/storage/servarr/bazarr 0755 root root -"

    "d /srv/media 0755 root media -"
    "d /srv/media/library 0750 media media -"
    "d /srv/media/library/movies 0750 media media -"
    "d /srv/media/library/series 0750 media media -"
    "d /srv/media/library/music 2770 media media -"
    "d /srv/media/library/books 2770 media media -"
    "d /srv/media/downloads 0775 media media -"
    "d /srv/media/downloads/complete 0775 media media -"
    "d /srv/media/downloads/complete/movies 0750 media media -"
    "d /srv/media/downloads/complete/series 0750 media media -"
    "d /srv/media/downloads/complete/lidarr 0750 media media -"
    "d /srv/media/downloads/complete/lazylibrarian 0750 media media -"
    "d /srv/media/downloads/complete/bazarr 0750 media media -"
    "d /srv/media/downloads/incomplete 0775 media media -"
    "d /srv/media/Incoming 0750 media media -"
    "d /srv/media/Documents 2770 media media -"
    "d /srv/media/Obsidian 0750 media media -"
    "d /srv/media/Repos 2770 media media -"
    "d /srv/media/Archive 0750 media media -"
    "d /srv/media/Pictures 2770 media media -"
    "d /srv/media/Pictures/Wallpapers 0750 media media -"
    "d /srv/media/Pictures/Photos 0750 media media -"
    "d /srv/media/Pictures/Screenshots 0750 media media -"
    "d /nix/storage/tdarr 0750 media media -"
    "d /nix/storage/qbittorrent 0750 media media -"
    "d /nix/storage/jellyseerr 0770 media media -"
  ];

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/nix/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      X11Forwarding = false;
    };
  };

  systemd.services."generate-ssh-keys" = {
    description = "Generate SSH host keys if missing";
    wantedBy = [ "multi-user.target" ];
    before = [
      "sshd.service"
      "sops-install-secrets.service"
    ];
    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
    ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 30;
    };
    script = ''
      set -e

      PERSIST_DIR="/nix/persist/etc/ssh"
      ETC_SSH="/etc/ssh"

      mkdir -p "$PERSIST_DIR"
      chmod 755 "$PERSIST_DIR"

      mkdir -p "$ETC_SSH"
      chmod 755 "$ETC_SSH"

      echo "Checking SSH host keys in $PERSIST_DIR..."

      if [ ! -f "$PERSIST_DIR/ssh_host_ed25519_key" ]; then
        echo "[SSH] Generating ED25519 host key..."
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$PERSIST_DIR/ssh_host_ed25519_key" -N "" -C "" 2>&1 | grep -v "overwrite"
        chmod 600 "$PERSIST_DIR/ssh_host_ed25519_key"
        chmod 644 "$PERSIST_DIR/ssh_host_ed25519_key.pub"
      fi

      if [ ! -f "$PERSIST_DIR/ssh_host_rsa_key" ]; then
        echo "[SSH] Generating RSA host key..."
        ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "$PERSIST_DIR/ssh_host_rsa_key" -N "" -C "" 2>&1 | grep -v "overwrite"
        chmod 600 "$PERSIST_DIR/ssh_host_rsa_key"
        chmod 644 "$PERSIST_DIR/ssh_host_rsa_key.pub"
      fi

      echo "[SSH] Verifying SSH keys..."
      ls -la "$PERSIST_DIR"/ssh_host_* 2>/dev/null | head -10

      if [ -d "$ETC_SSH" ]; then
        for key in "$PERSIST_DIR"/ssh_host_*; do
          if [ -f "$key" ]; then
            basename=$(basename "$key")
            if [ ! -L "$ETC_SSH/$basename" ] && [ ! -f "$ETC_SSH/$basename" ]; then
              echo "[SSH] Linking $basename to /etc/ssh"
              ln -sf "$key" "$ETC_SSH/$basename" 2>/dev/null || true
            fi
          fi
        done
      fi

      echo "[SSH] SSH key generation complete"
    '';
  };

  systemd.services = {

    "create-machine-id" = {
      description = "Create machine ID";
      wantedBy = [ "multi-user.target" ];
      before = [ "systemd-machine-id-commit.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [[ ! -f /etc/machine-id ]]; then
          ${pkgs.systemd}/bin/systemd-machine-id-setup
        fi
      '';
    };

    "ensure-storage" = {
      description = "Ensure storage directories exist";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      before = [
        "sonarr.service"
        "radarr.service"
        "lidarr.service"
        "prowlarr.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        TimeoutStartSec = "5min";
      };
      script = ''
        mkdir -p /nix/storage/{run/secrets,secrets,llm,syncthing,tdarr,qbittorrent,jellyseerr,jellyfin,homepage,nextcloud}
        mkdir -p /nix/storage/var/lib/vols/{portainer,watchtower}
        mkdir -p /nix/storage/vaultwarden/backups
        chown -R vaultwarden:vaultwarden /nix/storage/vaultwarden 2>/dev/null || true
        chmod 700 /nix/storage/vaultwarden 2>/dev/null || true
        mkdir -p /srv/media/library/{movies,series,music,books}
        mkdir -p /srv/media/Pictures/{Wallpapers,Photos,Screenshots}
        mkdir -p /srv/media/downloads/complete/{movies,series,lidarr,lazylibrarian,bazarr}
        mkdir -p /srv/media/downloads/incomplete
        mkdir -p /srv/media/{Incoming,Documents,Obsidian,Repos,Archive,Pictures}

        mkdir -p /nix/storage/servarr/{prowlarr,sonarr,radarr,lidarr,bazarr}
        mkdir -p /nix/storage/{tdarr,qbittorrent,jellyseerr}

        mkdir -p /nix/storage/llm-services/text-generation-webui

        chown -R media:media /nix/storage/servarr 2>/dev/null || true
        chown -R media:media /nix/storage/{tdarr,qbittorrent,jellyseerr} 2>/dev/null || true
        chmod -R 750 /nix/storage/servarr 2>/dev/null || true
        chmod -R 750 /nix/storage/{tdarr,qbittorrent,jellyseerr} 2>/dev/null || true
        chmod -R 755 /nix/storage/llm-services 2>/dev/null || true

        chown media:media /srv/media 2>/dev/null || true
        chmod 0755 /srv/media 2>/dev/null || true
        find /srv/media -mindepth 1 -maxdepth 1 -exec chown media:media {} + 2>/dev/null || true
        find /srv/media -mindepth 1 -maxdepth 1 -exec chmod 0755 {} + 2>/dev/null || true

        if command -v setfacl &> /dev/null; then
          setfacl -R -m u:1000:rwx /nix/storage/servarr 2>/dev/null || true
          setfacl -m u:1000:rwx /srv/media 2>/dev/null || true
          find /srv/media -mindepth 1 -maxdepth 1 -exec setfacl -m u:1000:rwx {} + 2>/dev/null || true
        fi

      '';
    };

    "sops-install-secrets" = {
      serviceConfig.ConditionFileNotEmpty = lib.mkForce "";
      unitConfig.OnFailure = lib.mkForce [ ];
    };
  };

  security = {
    sudo.wheelNeedsPassword = false;
    protectKernelImage = true;
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  users.users.diego = {
    isNormalUser = true;
  };
};
}
