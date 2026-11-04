{ config, ... }@top:
{
  flake.modules.homeManager.rubi =
    {
      config,
      lib,
      pkgs,
      inputs,
      customPkgs,
      desktop ? null,
      privateConfig ? { },
      ...
    }:
    let
      litellmFree = import ./features/ai/_litellm-free.nix {
        inherit lib;
        url = "http://cobalto:4000/v1";
      };
    in
    {
      home.file = litellmFree.pi;

      custom.git.signingKey = "~/.ssh/keys/git_ed25519.pub";

      colorscheme.mode = "dark";
      colorscheme.type = "material-darker";
      colorscheme.iconFolderColor = "black";
      colorscheme.specialisations = { };

      imports = with top.config.flake.modules.homeManager; [
        global
        cli
        cli-ekphos-theme
        cli-rmpc
        cli-zathura
        desktop-common
        desktop-sway
        desktop-zennotes-theme
        ai
      ];

      home.packages = [
        customPkgs.coderabbit-cli
        customPkgs.ekphos
        pkgs.insync
        pkgs.nodejs_24
      ];

      # Same pattern as OBSIDIAN in syncthing.nix; Insync's folder is set per account (`insync account add -p`)
      xdg.userDirs.extraConfig.DRIVES = "${config.home.homeDirectory}/Drives";

      systemd.user.services.insync = {
        Unit = {
          Description = "Insync";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          # `insync start` daemonizes out of reach of systemd's PID tracking, so keep the unit
          # active after the launcher exits; otherwise systemd cleans up the cgroup and kills the daemon
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.insync}/bin/insync start";
          ExecStop = "${pkgs.insync}/bin/insync quit";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      programs.nushell.shellAliases.hermes-cobalto = "ssh -t cobalto sudo -u hermes /run/current-system/sw/bin/hermes-tui";

      programs.obsidian = {
        enable = true;
        vaults.Notes.target = "Notes";
      };

      gtk.gtk3.bookmarks = [
        "file://${config.home.homeDirectory}/Documents"
        "file://${config.home.homeDirectory}/Downloads"
        "file://${config.home.homeDirectory}/Pictures"
        "file://${config.home.homeDirectory}/Projects"
        "file:///mnt/cobalto/media Cobalto media"
        "file:///mnt/cobalto/storage Cobalto storage"
      ];

      # ============================================================================
      # OpenCode - Single unified profile
      # ============================================================================
      programs.opencode-config = {
        enable = true;

        # Disable separate provider packages
        opencodeGo.enable = false;
        opencodeZen.enable = false;

        # Merge work config if available
        extraConfig = privateConfig.opencodeConfig or { };

        # Telegram notifications
        channels.telegram.enable = true;
        notifications.telegram = {
          enable = true;
          enableShellHook = false;
        };

        # Single profile named "default"
        profiles.default = {
          scriptName = "ocs";

          mcpServers = [
            "nixos"
            "github"
            "playwright"
            "zennotes"
          ];

          # big-pickle stays the default: this profile also loads work config, and
          # the LiteLLM free pool on cobalto includes providers that train on
          # prompts. The pool is added as a provider to pick by hand.
          config = lib.recursiveUpdate {
            model = "opencode/big-pickle";
            small_model = "opencode/big-pickle";

            # Providers
            provider = {
              "opencode" = {
                npm = "@ai-sdk/openai-compatible";
                name = "OpenCode Zen";
                options = {
                  baseURL = "https://opencode.ai/zen/v1";
                  apiKey = "{env:OPENCODE_API_KEY}";
                };
                models."big-pickle" = {
                  name = "Big Pickle";
                };
              };

              "opencode-go" = {
                npm = "@ai-sdk/openai-compatible";
                name = "OpenCode Go";
                options = {
                  baseURL = "https://opencode.ai/zen/go/v1";
                  apiKey = "{env:OPENCODE_API_KEY}";
                };
                models = {
                  "deepseek-v4-pro" = {
                    name = "DeepSeek V4 Pro";
                  };
                  "deepseek-v4-flash" = {
                    name = "DeepSeek V4 Flash";
                  };
                  "kimi-k2.6" = {
                    name = "Kimi K2.6";
                  };
                };
              };

              "local-llm" = {
                npm = "@ai-sdk/openai-compatible";
                name = "Local LLM (Ollama)";
                options = {
                  baseURL = "http://localhost:11434/v1";
                  apiKey = "ollama";
                };
                models = {
                  "qwen3:4b" = {
                    name = "Qwen3 4B (local, fast)";
                    limit = {
                      context = 32768;
                      output = 8192;
                    };
                  };
                  "qwen2.5-coder:7b" = {
                    name = "Qwen2.5 Coder 7B (local, code)";
                    limit = {
                      context = 32768;
                      output = 8192;
                    };
                  };
                  "qwen2.5-coder:14b" = {
                    name = "Qwen2.5 Coder 14B (local, strong code)";
                    limit = {
                      context = 32768;
                      output = 8192;
                    };
                  };
                  "deepseek-r1:8b" = {
                    name = "DeepSeek R1 8B (local, reasoning)";
                    limit = {
                      context = 16384;
                      output = 8192;
                    };
                  };
                };
              };
            }
            // (privateConfig.opencodeProviders or { });

            # Agent configuration
            agent = {
              title.model = "opencode/big-pickle";
              summary.model = "opencode/big-pickle";
              compaction.model = "opencode/big-pickle";
              plan.model = "opencode/big-pickle";
              build.model = "opencode/big-pickle";
              general.model = "opencode/big-pickle";

              # Subagents for heavy tools
              browser = {
                description = "Web/browser automation via Playwright MCP.";
                mode = "subagent";
                tools."playwright_*" = true;
              };
              github = {
                description = "GitHub operations via the GitHub MCP server.";
                mode = "subagent";
                tools."github_*" = true;
              };
            };

            # Disable heavy tools globally, subagents use them
            tools = {
              "github_*" = false;
              "playwright_*" = false;
            };
          } { inherit (litellmFree.opencode) provider; };
        };

        # Dispatcher maps profile to script
        dispatcher.contexts.default = {
          scriptName = "ocs";
          apiKeyEnvVar = "OPENCODE_API_KEY";
        };

        # Secret environment
        secretEnv = (privateConfig.workSecretEnv or { }) // {
          OPENCODE_API_KEY = "/run/secrets/opencode-api-key";
        };

        # Custom commands
        commands = {
          "review" = ''
            ---
            description: Run CodeRabbit AI review on uncommitted changes or against base branch
            argument-hint: "[--type uncommitted | --base main]"
            tools:
              bash: true
            ---
            <objective>
            Run CodeRabbit CLI review on the current workspace.
            </objective>

            <context>
            User arguments: $ARGUMENTS
            </context>

            <process>
            1. Parse $ARGUMENTS:
               - If `--type uncommitted` or no flag: `cr review --agent --type uncommitted`
               - If `--base <branch>`: `cr review --agent --base <branch>`
               - Otherwise: `cr review --agent --type uncommitted`
            2. Run the command and capture JSON output
            3. Present findings in three tiers: **Critical**, **Warning**, **Info**
            4. If user asks to fix issues, apply them directly
            </process>
          '';
        };
      };

      # ============================================================================
      # Claude Code
      # ============================================================================
      programs.claude-code-config.commands = {
        "review" = {
          description = "Run CodeRabbit AI review on uncommitted changes or against base branch";
          prompt = "Run `cr review --agent --type uncommitted` and present findings as Critical/Warning/Info tiers.";
        };
      };

      # ============================================================================
      # Skills
      # ============================================================================
      programs.ai-skills.enable = true;
    }

  ;
}
