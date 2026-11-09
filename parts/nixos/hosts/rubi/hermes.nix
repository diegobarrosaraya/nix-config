# Hermes on rubi: the laptop variant of ai-hermes-agent, a brief and a drift report each morning.
# Design: docs/superpowers/specs/2026-11-09-hermes-on-rubi-design.md
{ config, inputs, ... }@top:
{
  flake.modules.nixos.rubi-hermes =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.hermes-agent;
      home = "${cfg.stateDir}/.hermes";
      # The only account on this host. The name comes from the private repo.
      account = "claude-token-servicerocket";
      envContent = ''
        ANTHROPIC_TOKEN=${config.sops.placeholder.${account}}
      ''
      # Optional: swap a rejected subscription token for an API key without code changes.
      + lib.optionalString config.custom.hermes.apiKeySecret ''
        ANTHROPIC_API_KEY=${config.sops.placeholder."anthropic-api-key"}
      '';

      # Repos whose owner is one of these count as Diego's own tools.
      owners = [ "diegobarrosaraya" "DiegoBarrosA" ];
      clones = [ "nix-config" "nix-private-config" "nix-ai-tooling" ];

      # Compares each own-repo input in the locks of Hermes's clones with the remote default branch.
      # Read-only: git ls-remote through the system credential helper (https, no ssh key).
      drift = pkgs.writeShellApplication {
        name = "hermes-drift";
        runtimeInputs = [ pkgs.jq pkgs.git pkgs.coreutils pkgs.gnused ];
        text = ''
          export GIT_TERMINAL_PROMPT=0
          for repo in ${lib.concatStringsSep " " clones}; do
            lock=${cfg.workingDirectory}/$repo/flake.lock
            if [ ! -r "$lock" ]; then
              echo "$repo: no-clone (no $lock)"
              continue
            fi
            jq -r '.nodes as $n | .nodes.root.inputs | to_entries[]
                   | select(.value | type == "string") | .key as $k | $n[.value].locked
                   | select(.type == "github" or .type == "git")
                   | [$k, (.owner // ""), (.url // ""), (.repo // ""), .rev] | @tsv' "$lock" |
            while IFS=$'\t' read -r name owner url r rev; do
              if [ -n "$owner" ]; then url="https://github.com/$owner/$r.git"; fi
              url=$(echo "$url" | sed -E 's#^(ssh://)?git@github.com[:/]#https://github.com/#')
              case "$url" in
                ${lib.concatMapStringsSep "|" (o: "https://github.com/${o}/*") owners}) ;;
                *) continue ;;
              esac
              if remote=$(git ls-remote "$url" HEAD 2>/dev/null | cut -f1) && [ -n "$remote" ]; then
                if [ "$remote" = "$rev" ]; then s=same; else s=MOVED; fi
                echo "$repo lock input $name: locked=''${rev:0:8} remote=''${remote:0:8} $s"
              else
                echo "$repo lock input $name: locked=''${rev:0:8} remote=? unreadable"
              fi
            done
          done
        '';
      };

      # One run of `hermes -z` in the briefer profile. The profile has the notes tools only.
      runner = name: prompt: pre: pkgs.writeShellScript "hermes-${name}" ''
        export HERMES_HOME=${home}/profiles/briefer
        date=$(${pkgs.coreutils}/bin/date +%F)
        path="Hermes/${name}/$date.md"
        ${pre}
        exec ${cfg.package}/bin/hermes -z "$(cat ${prompt})

        Note path: $path
        ''${data:+
        Drift data:
        $data}"
      '';
      job = name: desc: time: script: {
        services."hermes-${name}" = {
          description = desc;
          after = [ "network-online.target" "sops-install-secrets.service" "hermes-profiles.service" ];
          wants = [ "network-online.target" ];
          requires = [ "hermes-profiles.service" ];
          unitConfig = {
            RequiresMountsFor = [ cfg.stateDir ];
            # One run plus three retries in an hour.
            StartLimitIntervalSec = "1h";
            StartLimitBurst = 4;
          };
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            Environment = [ "HOME=${cfg.stateDir}" ];
            ExecStart = script;
            Restart = "on-failure";
            RestartSec = "5min";
            TimeoutStartSec = "20min";
          };
        };
        timers."hermes-${name}" = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = time;
            # A run missed while the laptop slept happens after wake.
            Persistent = true;
          };
        };
      };
      brief = job "brief" "Hermes start-of-day brief" "*-*-* 07:30:00" (runner "brief" ./hermes/brief.md "");
      monitor = job "monitor" "Hermes drift report on own tool repos" "*-*-* 07:00:00" (
        runner "monitor" ./hermes/monitor.md "data=$(${drift}/bin/hermes-drift)"
      );
    in
    {
      imports = with top.config.flake.modules.nixos; [
        ai-hermes-agent
        ai-hermes-profiles
        inputs.private-config.nixosModules.workAccountSecretsRubi
      ];

      options.custom.hermes.apiKeySecret = lib.mkEnableOption "the sops secret anthropic-api-key, added to hermes.env (turn on only after the key is in hosts/rubi/secrets.yaml)";

      config = {
        custom.hermes.laptop = true;

        sops.secrets.anthropic-api-key = lib.mkIf config.custom.hermes.apiKeySecret {
          owner = "root";
          mode = "0400";
        };

        # Only the Anthropic credential. No dashboard, Telegram, NVIDIA, Nous or LiteLLM key.
        sops.templates."hermes.env" = {
          content = envContent;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "hermes-agent.service" ];
        };
        # A profile home does not inherit hermes.env, so the briefer gets its own copy.
        sops.templates."hermes-briefer.env" = {
          content = envContent;
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
          restartUnits = [ "hermes-profiles.service" ];
        };

        # State, sessions and clones live here. Without this a reboot wipes them.
        environment.persistence."/nix/persist".directories = [
          {
            directory = cfg.stateDir;
            user = cfg.user;
            group = cfg.group;
            mode = "0750";
          }
        ];

        # Same job as on cobalto: the persisted state dir hides what activation made.
        systemd.services = {
          hermes-agent = {
            unitConfig.RequiresMountsFor = [ cfg.stateDir ];
            serviceConfig.ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o ${cfg.user} -g ${cfg.group} -m 2770 ${cfg.workingDirectory}";
          };
        } // brief.services // monitor.services;

        # Tools stripped to the notes tools: the brief and the report write notes and do nothing else.
        services.hermes-agent.profiles.briefer = {
          soul = ./hermes/soul.md;
          envFile = config.sops.templates."hermes-briefer.env".path;
          readOnly = true;
          settings = {
            model = {
              provider = "anthropic";
              default = "claude-sonnet-5-5";
            };
            fallback_providers = [ ];
            auxiliary = config.services.hermes-agent.settings.auxiliary;
            agent.disabled_toolsets = [ "delegation" "code_execution" "terminal" "file" "web" "browser" "skills" ];
            platform_toolsets.cli = [ ];
            tools.tool_search.enabled = "off";
            mcp_servers.notes = {
              inherit (cfg.mcpServers.notes) command args;
            };
          };
        };

        systemd.timers = brief.timers // monitor.timers;

        environment.systemPackages = [ drift ];
      };
    };
}
