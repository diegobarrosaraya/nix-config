{ config, ... }@top:
{
  flake.modules.nixos.rubi =
{
  inputs,
  lib,
  config,
  pkgs,
  desktop,
  ...
}:
{
  boot.kernelPackages = pkgs.linuxPackages_zen;

  imports = with top.config.flake.modules.nixos; [

    global
    users-diego

    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd
    rubi-hardware-configuration

    inputs.stylix.nixosModules.stylix


    network-tailscale
    network-cloudflare-warp
    rubi-sops
    rubi-cobalto-shares

    rubi-impermanence

    rubi-bootloader

    desktop-devices
    desktop-desktop-common

    # shortcut: the two extra `imports` levels put this module at the same
    # module-tree depth as a flake.modules.* reference, which keeps
    # environment.systemPackages merging in the pre-dendritic order (verified
    # with nix-diff). Drop the nesting if you no longer care about matching
    # the old /run/current-system/sw store path.
    { imports = [ { imports = [ inputs.private-config.nixosModules.work ]; } ]; }

    # replaces hosts/common/optional/desktop/select.nix for desktop = "sway";
    # kept last so its definitions merge in the same order as before.
    desktop-environments-sway
  ];

  console = {
    packages = [ pkgs.terminus_font ];
    font = "ter-v32b";
    earlySetup = true;
  };

  stylix.autoEnable = false;
  stylix.targets = {
    font-packages.enable = true;
    fontconfig.enable = true;
    console.enable = true;
    plymouth.enable = true;
    limine.enable = true;
  };

  documentation.nixos.enable = false;

  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "rd.systemd.show_status=false"
    "systemd.show_status=false"
    "udev.log_level=3"
    "nowatchdog"
    "amdgpu.gpu_recovery=1"
  ];

  nixpkgs.overlays = [ (final: prev: {
    noto-fonts-color-emoji = prev.noto-fonts-monochrome-emoji;
  }) ];

  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; }) (
      lib.filterAttrs (name: _: name != "private-config") inputs
    );
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      max-jobs = 8;
      cores = 2;
    };

    extraOptions = "!include /etc/nix/github-access-token.conf";
  };

  # ponytail: nix-daemon builds were eating all RAM and taking sway down with
  # them (OOM). Cap the cgroup so a build storm can't starve the desktop.
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "20G";
    MemoryMax = "24G";
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # ponytail: userspace OOM killer, kills memory hogs before kernel OOM
  # stalls the desktop under pressure.
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
  };

  environment.systemPackages = with pkgs; [

    pciutils
    usbutils
    lshw
    qt6.qtwayland
    sbctl
    openssl

  ];

  networking = {
    hostName = "rubi";
    networkmanager.enable = true;

    networkmanager.wifi.powersave = false;
    firewall = {
      enable = true;

      allowedTCPPorts = [ 22 22000 ];
      allowedUDPPorts = [ 22000 21027 ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  services.resolved.enable = true;

  services.tailscale.useRoutingFeatures = "client";

  systemd.services.tailscale-exit-node-guard = {
    description = "Clear the Tailscale exit node when amatista is unreachable";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.tailscale}/bin/tailscale status --json \
        | ${pkgs.jq}/bin/jq -e '.ExitNodeStatus' >/dev/null 2>&1 || exit 0
      if ! ${pkgs.tailscale}/bin/tailscale ping --c 3 --timeout 3s amatista >/dev/null 2>&1; then
        echo "amatista unreachable; clearing exit node"
        ${pkgs.tailscale}/bin/tailscale set --exit-node=
      fi
    '';
  };
  systemd.timers.tailscale-exit-node-guard = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "2min";
    };
  };

  automount.blacklistAppleNet = true;

  security.polkit.enable = true;
  security.polkit.enablePkexecWrapper = true;
  services.dbus.enable = true;

  security.sudo.wheelNeedsPassword = false;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
    AMD_VULKAN_ICD = "RADV";
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 64;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 512;
      };
    };

    wireplumber.extraConfig."99-disable-suspend" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_input.*"; }
            { "node.name" = "~alsa_output.*"; }
          ];
          actions.update-props = {
            "session.suspend-timeout-seconds" = 0;
          };
        }
      ];
    };
  };
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # geoclue2 disabled: only consumer was localtimed (auto timezone-by-location),
  # which is useless without it. Waybar's location-clock module reads
  # /etc/localtime directly, not geoclue.

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  hardware.brillo.enable = true;

  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother_HL-1202";
        location = "Home";
        deviceUri = "usb://Brother/HL-1200%20series";
        model = "drv:///brlaser.drv/br1200.ppd";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "Brother_HL-1202";
  };

  programs.nix-ld.enable = true;

  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      customPkgs = inputs.self.packages."x86_64-linux";
      privateConfig = inputs.private-config or { };
      inherit desktop;
    };
    users.diego = {
      imports = with top.config.flake.modules.homeManager; [
        inputs.stylix.homeModules.stylix
        colors
        kanshi
        monitors
        bar
        inputs.ai-tooling.homeManagerModules.opencode-config
        inputs.ai-tooling.homeManagerModules.mcp-config
        inputs.ai-tooling.homeManagerModules.antigravity-config
        inputs.ai-tooling.homeManagerModules.claude-code-config
        inputs.ai-tooling.homeManagerModules.cursor-config
        inputs.ai-tooling.homeManagerModules.ai-skills
        inputs.ai-tooling.homeManagerModules.ai-system-prompt
        inputs.private-config.homeManagerModules.workMcpConfig
        inputs.private-config.homeManagerModules.workExtras
        rubi
      ];
    };
  };

  system.activationScripts.home-manager-reapply = lib.mkAfter ''
    ${config.systemd.package}/bin/systemctl restart home-manager-diego.service
  '';

  system.stateVersion = "25.11";

  systemd.services.NetworkManager-wait-online.enable = false;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  boot.blacklistedKernelModules = [ "8250" ];

  users.users.diego.extraGroups = [ "docker" ];
}

  ;
}
