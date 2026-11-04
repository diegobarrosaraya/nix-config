{ config, ... }@top:
{
  flake.modules.nixos.cobalto =
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = with top.config.flake.modules.nixos; [

    global
    users-diego

    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
    cobalto-hardware-configuration

    network-tailscale
    desktop-devices
    network-hosts
    system-environment

    system-sops-secrets
    system-automated-storage
    system-offsite-backup
    system-postgres-backup
    cobalto-impermanence

    system-webtheming

    inputs.private-config.nixosModules.workSecrets

    desktop-amd-gpu-acceleration

    network-minerales-network

    ai-llama-cpp-server

    media-flaresolverr

    apps-homepage-native
    network-syncthing

    media-prowlarr
    media-sonarr
    media-radarr
    media-lidarr
    media-bazarr
    media-transmission

    media-jellyfin

    media-tdarr
    media-jellyseerr
    media-recyclarr
    media-aria2
    media-media-user

    media-snapcast

    media-media-directories

    network-samba
    network-pihole
    apps-home-assistant
    media-miniflux
    apps-go2rtc
    apps-cameras
    apps-vaultwarden
    media-music-assistant
    media-po-token-server
    apps-bookorbit

    ai-hermes-agent
    ai-hermes-profiles
    ai-litellm

    apps-zennotes

    system-systemdboot
  ];

  services.hermes-agent.profiles.coder-light = {
    soul = ../../optional/ai/hermes-roles/coder-light.md;
    settings = {
      # Placeholder copied from the live `coder` profile. A free-tier model sends
      # repo code to a free provider: pick the real model before private repos.
      model = {
        provider = "nous";
        default = "reflection/beam-1.0-501b-a23b:free";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      # Explicit list: an unset cli falls back to every toolset. The dispatcher
      # adds the kanban_* lifecycle tools itself.
      platform_toolsets.cli = [ "terminal" "file" "skills" "todo" ];
      skills.external_dirs = [
        "${inputs.superpowers}/skills"
        "${inputs.ponytail}/skills"
      ];
    };
  };

  # Not readOnly: it commits in the worktree. The terminal only starts the
  # claude-<account> wrapper; Claude Code does the coding. max_in_progress_per_profile
  # is one global int (Task 3), so there is no per-profile cap to set here.
  services.hermes-agent.profiles.coder-heavy = {
    soul = ../../optional/ai/hermes-roles/coder-heavy.md;
    settings = {
      # Placeholder, same as coder-light: Diego sets the real model.
      model = {
        provider = "nous";
        default = "reflection/beam-1.0-501b-a23b:free";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      platform_toolsets.cli = [ "terminal" "file" "todo" ];
      skills.external_dirs = [
        "${inputs.superpowers}/skills"
        "${inputs.ponytail}/skills"
      ];
    };
  };

  services.hermes-agent.profiles.planner = {
    soul = ../../optional/ai/hermes-roles/planner.md;
    # Not readOnly: it writes spec and plan files. It has no terminal, so it
    # cannot run git; kanban_create reaches workers without a toolset entry.
    settings = {
      # Placeholder, same as coder-light: Diego sets the real model.
      model = {
        provider = "nous";
        default = "reflection/beam-1.0-501b-a23b:free";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      platform_toolsets.cli = [ "file" "skills" "todo" "web" ];
      skills.external_dirs = [
        "${inputs.superpowers}/skills"
        "${inputs.ponytail}/skills"
      ];
    };
  };

  services.hermes-agent.profiles.reviewer = {
    soul = ../../optional/ai/hermes-roles/reviewer.md;
    envFile = config.sops.templates."hermes-nvidia.env".path;
    # No terminal: the reviewer must not be able to edit or run anything.
    readOnly = true;
    settings = {
      # Placeholder: Diego sets the real model. A different family from
      # coder-light so author and reviewer do not share blind spots. NIM is a
      # hosted free-ish tier, so the provider sees the files it reads and the summary.
      model = {
        provider = "nvidia";
        default = "nvidia/nemotron-3-ultra-550b-a55b";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      platform_toolsets.cli = [ "file" "skills" "todo" ];
      skills.external_dirs = [
        "${inputs.superpowers}/skills"
        "${inputs.ponytail}/skills"
      ];
    };
  };

  services.hermes-agent.profiles.tester = {
    soul = ../../optional/ai/hermes-roles/tester.md;
    settings = {
      # Placeholder, same as coder-light: Diego sets the real model.
      model = {
        provider = "nous";
        default = "reflection/beam-1.0-501b-a23b:free";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      # terminal runs the checks; no skills, so it cannot drift from the role.
      platform_toolsets.cli = [ "terminal" "file" "todo" ];
    };
  };

  services.hermes-agent.profiles.security = {
    soul = ../../optional/ai/hermes-roles/security.md;
    envFile = config.sops.templates."hermes-nvidia.env".path;
    # Reads only. No file tool: it could read the term file. terminal is allowed by the readonly check for this profile alone,
    # to run the scan and three read-only git commands; the prompt forbids anything else.
    readOnly = true;
    settings = {
      # Placeholder, same family as the reviewer so it differs from the coders.
      model = {
        provider = "nvidia";
        default = "nvidia/nemotron-3-ultra-550b-a55b";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      platform_toolsets.cli = [ "terminal" ];
      skills.external_dirs = [
        "${inputs.superpowers}/skills"
        "${inputs.ponytail}/skills"
      ];
    };
  };

  services.hermes-agent.profiles.integrator = {
    soul = ../../optional/ai/hermes-roles/integrator.md;
    # Not readOnly: it adds the remote. It is the only role the push guardrail
    # (pushProfiles) lets get a git credential.
    settings = {
      # Placeholder, same as coder-light: Diego sets the real model.
      model = {
        provider = "nous";
        default = "reflection/beam-1.0-501b-a23b:free";
      };
      agent.disabled_toolsets = [ "delegation" "code_execution" ];
      platform_toolsets.cli = [ "terminal" "file" "todo" ];
      skills.external_dirs = [
        "${inputs.superpowers}/skills"
        "${inputs.ponytail}/skills"
      ];
    };
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [

    spec-kit
    cursor-cli
  ];

  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; })
      (lib.filterAttrs (name: _: name != "private-config") inputs);
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
  };

  networking = {
    hostName = "cobalto";
    useDHCP = false;
    interfaces = {
      enp7s0 = {
        useDHCP = true;
        ipv4.addresses = [
          {
            address = "10.0.0.1";
            prefixLength = 16;
          }
          {
            address = "192.168.1.85";
            prefixLength = 24;
          }
        ];
      };
    };
    firewall.allowedTCPPorts = [
      21063
      1984 8554 8555 8557
      51413
    ];
    firewall.allowedUDPPorts = [
      50000 50001 50002 50003 50004 50005
      51413
    ];
    firewall.trustedInterfaces = [ "tailscale0" ];
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  networking.pihole.enable = true;

  security.polkit.enable = true;
  services.dbus.enable = true;
  security.sudo.wheelNeedsPassword = false;

  services.tailscale.useRoutingFeatures = "both";

  systemd.services.wan-sqm = {
    description = "CAKE SQM on WAN egress (anti-bufferbloat)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      TC=${pkgs.iproute2}/bin/tc
      DEV=enp7s0
      WAN_RATE=200mbit

      $TC qdisc del dev $DEV root 2>/dev/null || true

      $TC qdisc add dev $DEV root handle 1: htb default 10
      $TC class add dev $DEV parent 1: classid 1:10 htb rate 1000mbit ceil 1000mbit
      $TC class add dev $DEV parent 1: classid 1:20 htb rate 1000mbit ceil 1000mbit
      $TC qdisc add dev $DEV parent 1:10 handle 10: cake bandwidth $WAN_RATE nat dual-srchost
      $TC qdisc add dev $DEV parent 1:20 handle 20: fq_codel

      $TC filter add dev $DEV parent 1: protocol ip prio 1 u32 match ip dst 192.168.0.0/16 flowid 1:20
      $TC filter add dev $DEV parent 1: protocol ip prio 1 u32 match ip dst 10.0.0.0/8 flowid 1:20
      $TC filter add dev $DEV parent 1: protocol ip prio 1 u32 match ip dst 100.64.0.0/10 flowid 1:20
      $TC filter add dev $DEV parent 1: protocol ipv6 prio 2 u32 match ip6 dst fd7a:115c:a1e0::/48 flowid 1:20
      $TC filter add dev $DEV parent 1: protocol ipv6 prio 2 u32 match ip6 dst fe80::/10 flowid 1:20
    '';
  };

  hardware.graphics.enable32Bit = false;

  users.users.diego.linger = true;

  services.cameras = {
    enable = true;
    reolink = {
      enable = true;
      ip = "192.168.1.19";
      rtspPort = 8554;
    };
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.matter-server.enable = true;

  boot.extraModprobeConfig = "options vfio-pci ids=10ec:818b";

  services.zennotes = {
    enable = true;
    vaultPath = "/srv/media/Obsidian/obsidiana";
  };

  services.po-token-server.enable = true;

  backups.restic = {
    enable = true;
    # Keep the repo off /nix/storage: the module default put it on the very
    # disk it backs up, so a single disk failure took out the data and its
    # local backups together. /srv/media is a separate physical disk.
    localRepo = "/srv/media/restic";
    remote = {
      bucket = "bitwarden-backup";
      envFile = config.sops.templates."restic.env".path;
    };
    # Syncthing only replicates these, it doesn't version them: a bad sync
    # propagates deletions/corruption to every device. restic gives them
    # real history.
    sources = [
      "/srv/media/Obsidian/obsidiana"
      "/srv/media/Repos"
    ];
    extraRemotes.proton = {
      repo = "rclone:proton:cobalto-backups";
      envFile = config.sops.templates."restic-proton.env".path;
    };
  };

  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      customPkgs = inputs.self.packages."x86_64-linux";
      privateConfig = inputs.private-config or { };
      desktop = null;
      theme = { scheme = "material-darker"; mode = "dark"; };
      isNixOnDroid = false;
    };
    users.diego = {
      imports = with top.config.flake.modules.homeManager; [
        inputs.stylix.homeModules.stylix
        colors
        monitors
        bar
        inputs.ai-tooling.homeManagerModules.opencode-config
        inputs.ai-tooling.homeManagerModules.mcp-config
        inputs.ai-tooling.homeManagerModules.jcode-config
        inputs.ai-tooling.homeManagerModules.antigravity-config
        inputs.ai-tooling.homeManagerModules.claude-code-config
        inputs.ai-tooling.homeManagerModules.agent-accounts
        inputs.ai-tooling.homeManagerModules.claude-desktop-config
        inputs.ai-tooling.homeManagerModules.cursor-config
        inputs.ai-tooling.homeManagerModules.ai-skills
        inputs.ai-tooling.homeManagerModules.ai-system-prompt
        inputs.private-config.homeManagerModules.workMcpConfig
        cobalto
      ];
    };
  };

  # Re-run home-manager on every switch, same as rubi.
  system.activationScripts.home-manager-reapply = lib.mkAfter ''
    ${config.systemd.package}/bin/systemctl restart home-manager-diego.service
  '';

  system.stateVersion = "22.11";

  services.llama-cpp-server = {
    enable = true;

    # Absolute path -> llama-server gets -m instead of -hf. The HuggingFace
    # fetch fails at startup (and the old cache died with the storage disk),
    # so keep the weights local:
    #   curl -L -o /nix/storage/llm/models/Llama-3.2-3B-Instruct-Q8_0.gguf \
    #     https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q8_0.gguf
    model = "/nix/storage/llm/models/Llama-3.2-3B-Instruct-Q8_0.gguf";

    port = 11435;
    contextSize = 8192;
    gpuLayers = 99;
  };

  system.activationScripts.ensureNixStoreLayout = ''
    if [ ! -e /nix/store/version ]; then
      (echo '7' > /nix/store/version && chmod 444 /nix/store/version) || true
    fi
    if [ ! -d /nix/store/derivations ]; then
      (mkdir -p /nix/store/derivations && chmod 755 /nix/store/derivations) || true
    fi
  '';
}

  ;
}
