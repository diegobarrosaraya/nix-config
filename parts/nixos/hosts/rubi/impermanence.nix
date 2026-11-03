{ ... }:
{
  flake.modules.nixos.rubi-impermanence = {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  environment.persistence."/nix/persist" = {
    hideMounts = true;
    directories = [

      "/etc/nixos"
      "/etc/ssh"
      "/var/log"
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/sops-nix"

      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"

      "/var/lib/bluetooth"

       "/var/lib/tailscale"

       "/var/lib/cloudflare-warp"

       "/var/lib/sbctl"

      "/var/lib/cups"

      "/var/lib/pipewire"

      "/var/lib/lockdown"

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

      "/var/lib/systemd/credential.secret"
    ];

    users.diego = {
      directories = [
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "Projects"
        ".ssh"
        ".config"
        ".local"
        ".cache"

        ".config/syncthing"

      ];

      files = [ ];
    };
  };

  fileSystems."/nix/persist" = {
    device = "/dev/mapper/rubi-root";
    fsType = "btrfs";
    options = [
      "subvol=persist"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/rubi-root";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = lib.mkForce true;
  };

  boot.initrd.supportedFilesystems = [ "btrfs" ];

  boot.initrd.systemd.services.wipe-root = {
    description = "Wipe root subvolume and restore from blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "dev-mapper-rubi\\x2droot.device" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "2min";
      StandardOutput = "null";
      StandardError = "null";
    };
    script = ''
      mkdir -p /tmp
      MNTPOINT=$(mktemp -d)
      (
        mount -t btrfs -o subvol=/ /dev/mapper/rubi-root "$MNTPOINT"
        trap 'umount "$MNTPOINT"' EXIT

        mkdir -p "$MNTPOINT"/persist/var/{log,lib/{nixos,systemd}}
        mkdir -p "$MNTPOINT"/persist/etc/ssh

        if [ -e "$MNTPOINT/persist/dont-wipe" ]; then
          true
        else
          btrfs subvolume delete -R "$MNTPOINT/root" || true

          if [ ! -e "$MNTPOINT/root" ]; then
            btrfs subvolume create "$MNTPOINT/root"
          fi

          if [ ! -e "$MNTPOINT/root-blank" ]; then
            btrfs subvolume snapshot -r "$MNTPOINT/root" "$MNTPOINT/root-blank"
          else
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

    "d /nix/persist/etc 0755 root root -"
    "d /nix/persist/etc/ssh 0755 root root -"
    "d /nix/persist/var 0755 root root -"
    "d /nix/persist/var/log 0755 root root -"
    "d /nix/persist/var/lib 0755 root root -"
    "d /nix/persist/var/lib/sops-nix 0700 root root -"
    "d /nix/persist/home 0755 root root -"
    "d /nix/persist/home/diego 0755 diego users -"
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
      StandardOutput = "null";
      StandardError = "null";
    };
    script = ''
      set -e
      PERSIST_DIR="/nix/persist/etc/ssh"
      ETC_SSH="/etc/ssh"

      mkdir -p "$PERSIST_DIR"
      chmod 755 "$PERSIST_DIR"
      mkdir -p "$ETC_SSH"
      chmod 755 "$ETC_SSH"

      if [ ! -f "$PERSIST_DIR/ssh_host_ed25519_key" ]; then
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$PERSIST_DIR/ssh_host_ed25519_key" -N "" -C ""
        chmod 600 "$PERSIST_DIR/ssh_host_ed25519_key"
        chmod 644 "$PERSIST_DIR/ssh_host_ed25519_key.pub"
      fi

      if [ ! -f "$PERSIST_DIR/ssh_host_rsa_key" ]; then
        ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "$PERSIST_DIR/ssh_host_rsa_key" -N "" -C ""
        chmod 600 "$PERSIST_DIR/ssh_host_rsa_key"
        chmod 644 "$PERSIST_DIR/ssh_host_rsa_key.pub"
      fi
    '';
  };

  systemd.services."create-machine-id" = {
    description = "Create machine ID";
    wantedBy = [ "multi-user.target" ];
    before = [ "systemd-machine-id-commit.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "null";
      StandardError = "null";
    };
    script = ''
      if [[ ! -f /etc/machine-id ]]; then
        ${pkgs.systemd}/bin/systemd-machine-id-setup
      fi
    '';
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
