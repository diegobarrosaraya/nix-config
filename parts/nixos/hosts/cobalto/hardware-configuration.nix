{ ... }:
{
  flake.modules.nixos.cobalto-hardware-configuration = { config, lib, pkgs, modulesPath, inputs, ... }:
let hostname = config.networking.hostName;
in {
  imports = [
    inputs.disko.nixosModules.disko
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" "tpm_tis" "tpm_crb" ];

  boot.initrd.kernelModules = [ "r8169" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  disko.devices = {
    disk = {
      cobalto = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WDC_PC_SN520_SDAPNUW-256G-1002_183457800691";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
content = {
                  type = "luks";
                  name = "cobalto-root";
                  passwordFile = "/run/secrets/luks_passphrase";
                  settings = {
                    allowDiscards = true;
                    # Headless unlock order: TPM2 (unattended, PCR 0+7) -> FIDO2
                    # YubiKey fallback -> passphrase slot via initrd SSH (port 2222).
                    # Re-enroll TPM2 after firmware/Secure Boot changes:
                    #   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 \
                    #     --unlock-key-file=/run/secrets/luks-passphrase <device>
                    # FIDO2 (script: scripts/cobalto-luks-fido2-enroll.sh).
                    # Drop a YubiKey slot when lost:
                    #   cryptsetup luksKillSlot <device> <slot>
                    crypttabExtraOpts = [ "fido2-device=auto" "tpm2-device=auto" ];
                  };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];

                  subvolumes = {

                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };

                    "/persist" = {
                      mountpoint = "/nix/persist";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };

                    "/nix" = {
                      mountOptions = [ "compress=zstd" "noatime" ];
                      mountpoint = "/nix";
                    };

                    "/swap" = {
                      mountpoint = "/.swapvol";
                      swap = { swapfile.size = "36G"; };
                    };
                  };

                  mountpoint = "/partition-root";

                };
              };
            };
          };
        };
      };
      # Both data disks are whole-disk LUKS (no partition table) - that is how
      # they were actually provisioned after the disk swap, so keep disko
      # matching reality or a future disko run would repartition them.
      storage = {
        type = "disk";
        # WD5000LPVX (500G) died and was replaced; this is the ST1000LM024 (931G)
        # that took its bay. Previously held unrelated "onedrive" btrfs data - wiped.
        device = "/dev/disk/by-id/ata-ST1000LM024_HN-M101MBB_S31QJ9DH116618";
        content = {
          type = "luks";
          name = "cobalto-storage";
          passwordFile = "/run/secrets/luks_passphrase";
          settings.allowDiscards = true;
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            mountpoint = "/nix/storage";
            mountOptions = [ "compress=zstd" "nofail" "x-systemd.device-timeout=15" ];
          };
        };
      };
      media = {
        type = "disk";
        # ST3000DM001 (3TB) failed and was replaced with this WD20EARX (1.8T).
        device = "/dev/disk/by-id/ata-WDC_WD20EARX-00PASB0_WD-WCAZAF362077";
        content = {
          type = "luks";
          name = "cobalto-media";
          passwordFile = "/run/secrets/luks_passphrase";
          settings.allowDiscards = true;
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            mountpoint = "/srv/media";
            mountOptions = [ "compress=zstd" "nofail" "x-systemd.device-timeout=15" ];
          };
        };
      };
  };

  };

  networking.useDHCP = lib.mkDefault true;
  networking.interfaces.enp7s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      hostKeys = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];
      authorizedKeys = (import ../../../_ssh-keys.nix).initrd;
    };
  };

  boot.initrd.systemd.network = {
    enable = true;
    networks."10-enp7s0" = {
      matchConfig.Name = "enp7s0";
      networkConfig.DHCP = "no";
      addresses = [
        { Address = "192.168.1.85/24"; }
      ];
      routes = [
        { Gateway = "192.168.1.1"; }
      ];
    };
  };

  # Only root may gate switch-root. disko otherwise registers every luks device
  # here, which is what dropped the box into emergency mode after the disk swap:
  # initrd had no way to unlock the data disks, so their device units timed out
  # and took "Local File Systems" (and the whole boot) down with them.
  boot.initrd.luks.devices = lib.mkForce {
    "cobalto-root" = {
      device = "/dev/disk/by-id/nvme-WDC_PC_SN520_SDAPNUW-256G-1002_183457800691-part2";
      allowDiscards = true;
      crypttabExtraOpts = [ "fido2-device=auto" "tpm2-device=auto" ];
    };
  };

  # Data disks unlock in the real system instead, from a keyfile that lives on
  # the already-unlocked root filesystem. "nofail" keeps a dead or absent data
  # disk from blocking boot; the machine comes up with those mounts missing.
  # Keyfile is provisioned out of band:
  #   install -Dm400 <(head -c32 /dev/urandom) /nix/persist/luks/data.key
  #   cryptsetup luksAddKey <device> /nix/persist/luks/data.key
  environment.etc."crypttab".text = ''
    cobalto-storage /dev/disk/by-id/ata-ST1000LM024_HN-M101MBB_S31QJ9DH116618 /nix/persist/luks/data.key nofail,discard,x-systemd.device-timeout=15s
    cobalto-media   /dev/disk/by-id/ata-WDC_WD20EARX-00PASB0_WD-WCAZAF362077  /nix/persist/luks/data.key nofail,discard,x-systemd.device-timeout=15s
  '';

  # Legacy path kept during the /mnt/media -> /srv/media migration.
  # Remove once every consumer has been re-pointed.
  fileSystems."/mnt/media" = {
    device = "/srv/media";
    fsType = "none";
    # nofail: without it this bind inherits a hard dependency on /srv/media and
    # drags "Local File Systems" down whenever the media disk is unavailable.
    options = [ "bind" "nofail" ];
  };
};
}
