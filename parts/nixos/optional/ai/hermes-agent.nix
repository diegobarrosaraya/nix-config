{ inputs, ... }:
{
  flake.modules.nixos.ai-hermes-agent =
{ config, lib, pkgs, ... }:

let
  cfg = config.services.hermes-agent;
  hermesThemes = import ./_hermes-themes.nix { inherit inputs lib pkgs; };
  vault = "/srv/media/Obsidian/obsidiana";
  # Hermes may write only here. The rest of the vault is read-only for it.
  scratch = "${vault}/Hermes";

  # One ACP wrapper per Claude account that has a token. Hermes picks the
  # account by name: delegate_task with acp_command set to the wrapper's path.
  # Each wrapper keeps its own Claude config dir under the hermes state dir and
  # reads the token (group hermes, mode 0440) at start, so no token is in the store.
  claudeCfg = config.home-manager.users.diego.programs.claude-code-config;
  claudeAccounts = lib.filterAttrs (_: p: p.tokenFile != null) claudeCfg.profiles;
  # Same declared setup as diego's, reused from his evaluated home-manager
  # config: plugins and MCP servers for Claude, opencode.json for opencode.
  # The github server is left out: Hermes has its own read-only GitHub MCP and
  # keeps GH_TOKEN out of every shell on purpose.
  hmDiego = config.home-manager.users.diego;
  mcpServers = removeAttrs (
    hmDiego.programs.mcp-config.standardFormat.mcpServers // claudeCfg.extraMcpServers
  ) [ "github" ];
  # Plugins come from the store with --plugin-dir (claudeCliArgs), so no
  # enabledPlugins here: nothing is installed or fetched at run time. A headless
  # run cannot answer a permission prompt, so the Bash commands a code task
  # needs are allowed here and the ones that publish or destroy are denied.
  # Edits are accepted with --permission-mode acceptEdits, passed by Hermes.
  claudeSettings = pkgs.writeText "hermes-claude-settings.json" (
    builtins.toJSON {
      permissions = {
        allow = [
          "Bash(git:*)"
          "Bash(gh:*)"
          "Bash(nix flake check:*)"
          "Bash(nix eval:*)"
          "Bash(nix build:*)"
          "Bash(nix develop:*)"
          "Bash(nix fmt:*)"
          "Bash(bash:*)"
          "Bash(ls:*)"
          "Bash(cat:*)"
          "Bash(grep:*)"
          "Bash(find:*)"
          "Bash(mkdir:*)"
          "Bash(chmod:*)"
        ];
        deny = [
          "Bash(gh pr merge:*)"
          "Bash(git push --force:*)"
          "Bash(git push -f:*)"
          "Bash(git push origin main:*)"
          "Bash(git push origin master:*)"
        ];
      };
    }
  );
  # Superpowers and ponytail, pinned in flake.lock. The rules file is Diego's
  # dev rules adapted for headless runs (docs/agents/dev-rules.md).
  agentRules = ../../../../docs/agents/dev-rules.md;
  claudeMcp = pkgs.writeText "hermes-claude-mcp.json" (builtins.toJSON { inherit mcpServers; });
  # The MCP servers read their credentials from env vars, which diego's shell
  # fills from /run/secrets (cli/mcp.nix). The wrappers do the same here; the
  # secrets are group-readable by hermes (see sops.secrets below).
  mcpEnv = lib.filterAttrs (
    n: _: lib.any (p: lib.hasPrefix p n) [ "WORK_" "JIRA_" "CONFLUENCE_" "JSM_" "TRELLO_" "TEMPO_" ]
  ) (inputs.private-config.workSecretEnv or { });
  exportMcpEnv = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      n: path: ''[ -r ${path} ] && export ${n}="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < ${path})"''
    ) mcpEnv
  );
  agyPackage =
    (import inputs.nixpkgs-acp {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).antigravity-cli;
  # bin is the command name, exe what it runs. The same token logic serves the
  # ACP wrapper (delegate_task) and the plain CLI (Hermes's claude-code skill).
  claudeBin =
    bin: exe: extraArgs: name: p:
    pkgs.writeShellScriptBin bin ''
      token="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < ${lib.escapeShellArg p.tokenFile} 2>/dev/null || true)"
      if [ -z "$token" ]; then
        echo "${bin}: token file ${p.tokenFile} missing, empty or unreadable by $(${pkgs.coreutils}/bin/id -un)" >&2
        exit 1
      fi
      export CLAUDE_CODE_OAUTH_TOKEN="$token"
      export CLAUDE_CONFIG_DIR=${cfg.stateDir}/claude/${name}
      ${pkgs.coreutils}/bin/mkdir -p "$CLAUDE_CONFIG_DIR"
      ${exportMcpEnv}
      exec ${exe} ${extraArgs} "$@"
    '';
  # Git access for the agents' shell tools (git push, gh pr create) on GitHub,
  # GitLab and Bitbucket. Personal: the existing hermes-github-token. Work:
  # private-config workGit, by platform and customer, one token per entry
  # (Contents + Pull requests write only; "branches and PRs only" is a ruleset
  # on each repo, not something the token enforces). The token is picked by
  # host and repo owner. An owner that is in neither list gets no credentials.
  # Only the profiles in services.hermes-agent.pushProfiles (the integrator, default
  # for Hermes chat, and the temporary legacy coder exemption) get
  # a credential; a coder's `git push` fails at the helper.
  # No token enters an environment variable of the agent's shell: git reads
  # it through a credential helper, and gh gets it inside its own wrapper.
  gitAccess = lib.recursiveUpdate {
    github.personal = {
      host = "github.com";
      user = "x-access-token";
      owners = [ "diegobarrosa" ];
      tokenFile = "/run/secrets/hermes-github-token";
    };
  } (inputs.private-config.workGit or { });
  gitEntries = lib.concatMap lib.attrValues (lib.attrValues gitAccess);
  gitHosts = lib.unique (map (a: a.host) gitEntries);
  gitTable = lib.concatStringsSep "\n" (
    lib.concatMap (a: map (o: "${a.host} ${o} ${a.user} ${a.tokenFile}") a.owners) gitEntries
  );
  # Script and push guardrail live in pkgs/hermes-push-guard.nix so the check can test them.
  pushGuard = import ../../../../pkgs/hermes-push-guard.nix {
    inherit pkgs;
    profiles = cfg.pushProfiles;
    table = gitTable;
  };
  gitToken = pushGuard.token;
  gitCredential = pkgs.writeShellScript "git-credential-hermes" ''
    [ "''${1:-}" = get ] || exit 0
    host="" path=""
    while IFS='=' read -r k v; do
      case "$k" in host) host=$v ;; path) path=$v ;; esac
    done
    out="$(${gitToken} "$host" "''${path%%/*}")" || exit 0
    printf 'username=%s\npassword=%s\n' "''${out%% *}" "''${out#* }"
  '';
  ghWrapper = pkgs.writeShellScriptBin "gh" ''
    repo="" prev=""
    for a in "$@"; do
      case "$prev" in -R|--repo) repo=$a ;; esac
      case "$a" in --repo=*) repo=''${a#--repo=} ;; esac
      prev=$a
    done
    if [ -z "$repo" ]; then
      repo="$(${pkgs.git}/bin/git remote get-url origin 2>/dev/null || true)"
      repo=''${repo#*github.com[:/]}
    fi
    if out="$(${gitToken} github.com "''${repo%%/*}")"; then
      export GH_TOKEN="''${out#* }"
    fi
    exec ${pkgs.gh}/bin/gh "$@"
  '';
  claudeWrapper = name: claudeBin "hermes-claude-${name}" "${claudeCfg.acpPackage}/bin/claude-agent-acp" "" name;
  claudeCliArgs = lib.concatStringsSep " " [
    "--settings ${claudeSettings}"
    "--mcp-config ${claudeMcp}"
    "--plugin-dir ${inputs.superpowers}"
    "--plugin-dir ${inputs.ponytail}"
    "--append-system-prompt-file ${agentRules}"
  ];
  claudeCli = name: claudeBin "claude-${name}" "${pkgs.claude-code}/bin/claude" claudeCliArgs name;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    {
      options.services.hermes-agent.pushProfiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "integrator" "default" "coder" ];
        description = ''
          Hermes profiles whose shell may get git and gh credentials. An unset
          HERMES_PROFILE (Hermes chat) is always allowed. "coder" is a TEMPORARY
          legacy exemption: it is the undeclared live profile Diego uses today.
          Remove it when he retires `coder`. A guardrail, not a boundary.
        '';
      };
    }
  ];

  services.hermes-agent = {
    enable = true;
    environmentFiles = [ config.sops.templates."hermes.env".path ];

    # The security profile scans with gitleaks through hermes-security-scan.
    extraPackages = [ pkgs.gitleaks (import ../../../../pkgs/hermes-security-scan.nix { inherit pkgs; }) ];

    # Not a secret, so it may live in the Nix store. A non-loopback public URL
    # turns on the dashboard login gate (basic auth, set in hermes.env) even
    # though the backend binds loopback behind nginx. The dashboard also
    # accepts this hostname as the Host header.
    environment.HERMES_DASHBOARD_PUBLIC_URL = "https://hermes.minerales.network";

    # Chat runs on the Nous Portal free tier, so the paid OpenCode Go quota is
    # left for coding: Hermes chat emptied the Go weekly window on 2026-10-29.
    # The login is a device-code OAuth token in the Hermes home (hermes auth add
    # nous), not a declared secret. The model is one of the four :free ids the
    # Portal listed on 2026-10-31, all with tools; this one is the largest.
    # Vault notes reach a free provider: narrowing Hermes's vault access is open.
    settings.model = {
      provider = "nous";
      default = "reflection/beam-1.0-501b-a23b:free";
    };

    # One fallback only: hosted NIM. Two entries were removed on 2026-10-29:
    # glm-5.3 shares the Go workspace's 5-hour limit with kimi-k3, so it was
    # always exhausted when needed; the local Llama-3.2-3B has an 8K window, and
    # Hermes needs 64K to compress, so the turn died with a ValueError. When
    # both remaining providers are limited, Hermes should stop and say so.
    # NIM: /v1/models lists models the key cannot call;
    # nemotron-3-super-120b-a12b, kimi-k2.6 and two others returned 404 "Function
    # not found for account", while nemotron-3-ultra-550b-a55b and
    # minimax-m3.1-flash returned 200 (2026-10-28), so re-test before changing
    # ids. OpenCode Zen is left out: its free tier makes Hermes wait 600 s per
    # retry once capped.
    settings.fallback_providers = [
      {
        provider = "nvidia";
        model = "nvidia/nemotron-3-ultra-550b-a55b";
      }
    ];

    # Code work goes through the claude-<name> CLI, never through Hermes's own
    # subagents. A free NIM model drove delegate_task into a failed handover on
    # 2026-10-29. Lists in settings replace the live ones on deploy, so this is
    # applied even though config.yaml is merged. Terminal and file tools stay:
    # this does not stop a shell edit, only the AGENTS.md rules do that.
    settings.agent.disabled_toolsets = [ "delegation" "code_execution" ];

    # Conservative on purpose: one box, free-tier models with rate limits.
    # The per-profile cap stops fan-out onto a single profile. Review cards are
    # dispatched so reviewer profiles pick them up.
    settings.kanban = {
      review_dispatch = true;
      max_in_progress = 2;
      max_in_progress_per_profile = 1;
    };

    backend.mode = "dashboard";

    # rubi's two schemes as defaults: the dashboard theme and the CLI skin
    # each carry dark and light and follow the system or terminal setting.
    hermesHomeFiles = hermesThemes.files;
    settings.display.skin = "colors";
    settings.dashboard.theme = "colors";

    # GitHub access goes through an MCP server, so the token never enters the
    # agent's shell. Hermes blocks GH_TOKEN and GITHUB_TOKEN from every shell
    # subprocess (Tier-1 secrets) and refuses them in env_passthrough, so the
    # shell cannot use the token. The server process gets it because Hermes
    # expands ${GH_TOKEN} from its own environment (hermes.env) when it
    # connects. The literal ${GH_TOKEN} is what lands in config.yaml, not the
    # value. Read-only: drop --read-only to let it push and open PRs.
    # By default Hermes hides MCP tools behind tool_search / tool_describe /
    # tool_call, and tool_call needs nested {name, arguments} entries. Kimi K3
    # dropped the arguments through that bridge, so GitHub's tools are
    # exposed directly instead. The 1M-token context absorbs the extra schemas.
    settings.tools.tool_search.enabled = "off";

    # The notes vault through ZenNotes, Hermes's second brain. Same server as
    # diego's tools (`zn mcp`, vault set by custom.notesVault). It runs as the
    # hermes user on the files, not through the ZenNotes server (which runs as
    # diego), so the ACLs from hermes-vault-access still limit writes to Hermes/.
    mcpServers.notes = {
      command = hmDiego.programs.mcp-config.zennotes.cliPath;
      args = [ "mcp" ];
    };
    # Its bundled obsidian skill reads the vault with file tools instead.
    settings.skills.disabled = [ "obsidian" ];

    mcpServers.github = {
      command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
      args = [ "stdio" "--read-only" "--toolsets" "repos,issues,pull_requests" ];
      env.GITHUB_PERSONAL_ACCESS_TOKEN = "\${GH_TOKEN}";
    };
  };


  # Terminal TUI for diego, run as the install owner. The hermes install state
  # is writable only by the hermes user, so a plain `hermes` as diego fails on
  # .install.lock. The wrapper sets HERMES_HOME, so sudo needs no env passthrough.
  # rubi runs it as: ssh -t cobalto sudo -u hermes /run/current-system/sw/bin/hermes-tui
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "hermes-tui" ''
      export HERMES_HOME=${cfg.stateDir}/.hermes
      exec ${cfg.package}/bin/hermes --tui "$@"
    '')
    # Kanban CLI for Hermes's own terminal and for diego via sudo: creates and
    # reads cards. Workers do not use it, they have the kanban_* tools.
    (pkgs.writeShellScriptBin "hermes-kanban" ''
      export HERMES_HOME=${cfg.stateDir}/.hermes
      exec ${cfg.package}/bin/hermes kanban "$@"
    '')
  ]
  ++ [ ghWrapper ]
  ++ lib.mapAttrsToList claudeWrapper claudeAccounts
  ++ lib.mapAttrsToList claudeCli claudeAccounts
  # Hermes skills look for `claude` and `opencode` on PATH. Bare opencode exports
  # OPENCODE_API_KEY from the shared opencode-api-key secret; bare claude is personal.
  ++ [
    (pkgs.writeShellScriptBin "opencode" ''
      key="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < /run/secrets/opencode-api-key 2>/dev/null || true)"
      if [ -z "$key" ]; then
        echo "opencode: /run/secrets/opencode-api-key missing, empty or unreadable by $(${pkgs.coreutils}/bin/id -un)" >&2
        exit 1
      fi
      export OPENCODE_API_KEY="$key"
      # The task runner passes its own config (models pinned to the task's model).
      export OPENCODE_CONFIG="''${OPENCODE_CONFIG:-${hmDiego.xdg.configFile."opencode/opencode.json".source}}"
      ${exportMcpEnv}
      exec ${pkgs.opencode}/bin/opencode "$@"
    '')
  ]
  ++ lib.optional (claudeAccounts ? personal) (claudeBin "claude" "${pkgs.claude-code}/bin/claude" claudeCliArgs "personal" claudeAccounts.personal)
  ++ [
    # Antigravity CLI for Hermes. The Google login is manual, done once as the
    # hermes user (sudo -u hermes hermes-agy), and lives in agyHome, which sits
    # under the persisted /var/lib/hermes. Hermes runs it as a shell command:
    # hermes-agy -p "task" --output-format json
    (pkgs.writeShellScriptBin "hermes-agy" ''
      export HOME=${cfg.stateDir}/agy
      ${pkgs.coreutils}/bin/mkdir -p "$HOME"
      exec ${agyPackage}/bin/agy "$@"
    '')
  ];

  # Tells Hermes which coding agents exist. The module installs this into the
  # working directory, where Hermes reads it as project context. Names only, no secrets.
  # workingDirectory is pinned to the module default so `documents` accepts it.
  # Fonts for the dashboard themes, same-origin because its CSP allows only
  # 'self' and Google Fonts. Public font files, so no access rules here; the
  # vhost itself is in minerales-network.nix.
  services.nginx.virtualHosts."hermes.minerales.network".locations."${hermesThemes.fontPath}/" = {
    alias = "${hermesThemes.fonts}/";
    extraConfig = ''
      expires 30d;
      add_header Cache-Control "public, immutable";
    '';
  };

  services.hermes-agent.workingDirectory = "/var/lib/hermes/workspace";
  services.hermes-agent.documents."AGENTS.md" =
    ''
      # Coding agents on this host

      ## Second brain: the notes vault

      - Diego's notes vault is your knowledge base. Use the `notes` MCP (ZenNotes) for it: search
        it before you ask Diego, and read the project notes before you start work.
      - Do not read the vault with file tools or the shell. Use the `notes` tools.
      - You can write only under `Hermes/`. Every other folder is read-only for you. Put new notes
        and findings there, and tell Diego which note you wrote.

      ## Rules for code work (read first)

      - You are the dispatcher. You do not write code. Never edit, create or delete files in a repo yourself.
      - Never use delegate_task or execute_code to change code. Use a coding agent from the list below.
      - Start every code task in a fresh session. Send /new first. A /model switch is kept across
        restarts and sticks to the session, and /new clears it.
      - If a command fails twice with the same error, stop and tell Diego. Do not retry it again.
      - If every model you can use is rate limited, say so and stop. Do not go on with a weaker model.
      - Never push to a default branch. Never merge. The coding agent opens a PR. Diego merges.

      ## Code task flow

      1. Pick the account by repo owner (see Git access). Personal repos use `claude-personal`.
         Work repos use the account named for the client.
      2. Make a worktree. Do not touch the main checkouts in /var/lib/hermes/workspace.
         The base is the branch Diego names. If he names none, use the default branch:
         `git -C /var/lib/hermes/workspace/<repo> symbolic-ref --short refs/remotes/origin/HEAD`
         Never assume origin/main.
         `git -C /var/lib/hermes/workspace/<repo> fetch origin`
         `git -C /var/lib/hermes/workspace/<repo> worktree add /var/lib/hermes/workspace/wt/<repo>-<slug> -b hermes/<date>-<slug> <base>`
      3. Run the agent from inside the worktree, in the background, and save its JSON output in
         /var/lib/hermes/workspace/runs/. Command shape:
         `claude-<name> -p "<task>" --output-format json --permission-mode acceptEdits --max-budget-usd 3`
         The agent already has superpowers, ponytail and Diego's dev rules. Do not repeat them.
      4. Spec first. The first call asks for a spec only: "Use superpowers:brainstorming for this task: <task>."
         Read the JSON `result` and `session_id`. Send Diego a short summary of the spec and any question.
      5. Wait for Diego to approve. Then resume the same session:
         `claude-<name> --resume <session_id> -p "The spec is approved. Write the plan, then build it." --output-format json --permission-mode acceptEdits --max-budget-usd 5`
         If Diego asks for changes, resume with his changes and stay at the spec step.
      6. The agent runs the checks, pushes the branch and opens the PR. Send Diego the PR link and the check output.
      7. If a run ends with a question, send the question to Diego, then resume with his answer.
      8. If a run fails or stops, report what the JSON says. Do not finish the work yourself.

      ## Long jobs while Diego is away (Kanban)

      For a long coding job on a public or personal repo, do not start an agent yourself. Create a Kanban
      card with `hermes-kanban create` through the terminal. The gateway's dispatcher starts a worker on
      profile `coder` within a minute, and the card survives a crash or reboot. You only report.

      ```
      hermes-kanban create "<short title>" --assignee coder \
        --workspace worktree:/var/lib/hermes/workspace/<repo>/.worktrees/<slug> --branch hermes/<slug> \
        --max-runtime 3600 --body "<goal, base branch, files to read first, how to check the result>"
      ```

      - Clone the repo into /var/lib/hermes/workspace/<repo> first if it is missing. The worktree path
        must be inside that repo, or the card fails to spawn.
      - Name the base branch in the body. If Diego names none, use the default branch:
        `git -C /var/lib/hermes/workspace/<repo> symbolic-ref --short refs/remotes/origin/HEAD`.
      - Tell the worker in the body: commit, push the branch, open a PR, never push to a default branch,
        never merge.
      - Follow a card with `hermes-kanban show <id>` and `hermes-kanban list`. If a card is blocked,
        tell Diego the reason it shows. Do not unblock, promote or edit cards yourself.
      - For a whole project or a feature that needs review and tests, use "Team jobs" below instead of a single `coder` card.
      - Work and customer repos do not use Kanban yet: use the code task flow above.

      ## Team jobs (a whole project or a feature)

      For a whole project or a feature, create ONE card for profile `planner`. The planner inquires,
      writes the spec and plan, asks Diego for approval, then creates the chain itself: coders (`coder-light` for small
      cards, `coder-heavy` for cross-cutting work; each hands its own card to `reviewer`),
      `tester`, `security`, `integrator`, one after the other. Only the `integrator` pushes. You only report.

      ```
      hermes-kanban create "<short title>" --assignee planner \
        --workspace worktree:/var/lib/hermes/workspace/<repo>/.worktrees/<slug> --branch hermes/<slug> \
        --max-runtime 3600 --body "<what Diego wants, repo, base branch, any constraint he named>"
      ```

      - Same repo and worktree rules as the Kanban section above.
      - For a NEW project, set it up first (a setup step like cloning, it edits no files): create
        `/var/lib/hermes/workspace/<project>`, run `git init` and `git commit --allow-empty -m "chore: init"` there,
        then create the planner card with the worktree inside that repo. The `integrator` blocks until Diego
        creates the private remote by hand and unblocks it.
      - If a card is blocked with "escalate to coder-heavy", tell Diego and give him this command to run himself:
        `hermes-kanban reassign <id> coder-heavy`. The card stays blocked after that, so he also unblocks it
        (`hermes-kanban unblock <id>` or the dashboard). You never run either.
      - Do not edit, unblock or promote cards. Diego approves in the dashboard: he comments and unblocks there.
        A message in Hermes chat does not unblock a card.
      - Follow with `hermes-kanban show <id>`. Tell Diego when the planner blocks for approval, and its summary.
      - A blocked `tester` or `security` card has stopped the chain. Tell Diego its reason; for `security` that is FILE:LINE only, never matched text.
      - The `integrator` pushes the branch and opens the PR. The chain ends with its PR link. Send that to Diego, and for nix-config jobs the
        deploy command the `integrator` gives. You never deploy.

      ## Tools

      ## Claude Code (one command per account)
      - `claude -p "task"` is the personal account.
    ''
    + lib.concatMapStrings (n: "- `claude-${n} -p \"task\"`\n") (lib.attrNames claudeAccounts)
    + ''
      - Pick the account by name. The names are the client or purpose each account belongs to.

      ## Antigravity (Google)
      - `hermes-agy -p "task" --output-format json`

      ## OpenCode
      - `opencode run --model opencode-go/<model> "task"`. List models with `opencode models`.
        Use the paid `opencode-go/...` models. Free `opencode/...` models
        can hit the free-tier cap and hang.

      ## Git access
      - `git push` and `gh` work without any login step. Credentials depend on the repo owner.
      - In Team jobs only the `integrator` profile gets credentials (services.hermes-agent.pushProfiles). A coder's push fails.
      - Personal repos (DiegoBarrosA): full access.
      - Work repos: create branches and open PRs only. Never push to the default branch,
        never merge. Open a PR and leave the merge to Diego.
      - A repo owner that is not configured has no credentials, so a push fails. Do not look
        for tokens elsewhere. Tell Diego.

      ## Not installed
      - Codex CLI.
    '';

  security.sudo.extraRules = [
    {
      users = [ "diego" ];
      runAs = cfg.user;
      commands = [
        {
          command = "/run/current-system/sw/bin/hermes-tui";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/hermes-agy";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # The MCP secrets are owned by diego (group users, 0400). Hermes's wrappers
  # read them, so give group hermes read access. Names come from the same
  # secretEnv map as diego's shell, so the two stay in step.
  sops.secrets = {
    # Personal git token, also read by the credential helper and gh wrapper.
    hermes-github-token = {
      group = "hermes";
      mode = "0440";
    };
  } // lib.mapAttrs' (
    _: path:
    lib.nameValuePair (baseNameOf path) {
      group = lib.mkForce "hermes";
      mode = lib.mkForce "0440";
    }
  ) mcpEnv;

  # System git config, applied because the service HOME is /var/lib/hermes
  # (no ~/.gitconfig). The helper (see gitAccess above) hands out the personal
  # or work token by host and repo owner. useHttpPath makes git pass the
  # owner/repo path, which the helper needs.
  # In personal repos Hermes commits as Azogue bot, not under an AI name
  # (parts/nixos/global/ai-attribution.nix). diego's own ~/.config/git/config
  # is read after the system file, so his identity still wins for him.
  custom.aiAttribution.gitConfig.user = {
    name = "Azogue bot";
    email = "azogue@minerales.network";
  };

  programs.git = {
    enable = true;
    config = {
      # Default identity in an [include], which git reads before the personal
      # [includeIf] (sections are written sorted), so Azogue wins there. A plain
      # [user] section sorts last and would override it (checks.ai-attribution-scope).
      include.path = "${pkgs.writeText "hermes-identity.gitconfig" ''
        [user]
        	name = Hermes
        	email = hermes@minerales.network
      ''}";
      credential = lib.listToAttrs (
        map (h: lib.nameValuePair "https://${h}" {
          useHttpPath = true;
          helper = "${gitCredential}";
        }) gitHosts
      );
    };
  };

  # /var/lib/hermes is an impermanence bind mount. It hides the workspace that
  # activation made, and the backend started before tmpfiles recreated it
  # (status=200/CHDIR), which failed the switch. Wait for the mount and create
  # the directory as root before the unit changes into it.
  systemd.services.hermes-backend = {
    unitConfig.RequiresMountsFor = [ cfg.stateDir ];
    serviceConfig.ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o ${cfg.user} -g ${cfg.group} -m 2770 ${cfg.workingDirectory}";
  };

  # ProtectSystem=strict makes /srv read-only for the units. Open the
  # scratch folder only, for the gateway and for the dashboard's chat TUI.
  systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [ scratch ];

  # The gateway drains running agents for up to 1885 s on a restart. The
  # default stop timeout is 90 s, which cut running tasks off on every deploy.
  # A deploy now waits for a running task to finish, up to this long.
  systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = 1900;

  # Deploy race (seen 2026-10-29): while hermes-agent was stopped, the dashboard
  # found no gateway and started its own `gateway run --idle-exit`. That stray
  # held the host lock, so the real unit exited 75 and looped, and the stray ran
  # outside the unit's cgroup and drain timeout. Hermes looks for a supervising
  # unit named hermes-gateway.service (hermes_cli/gateway_runtime_service.py
  # _systemd) and starts a stray only when it finds none. This alias makes it
  # find one. It cannot verify our unit's identity (EnvironmentFile, ExecStartPre),
  # so it refuses to start a gateway itself and reports the gateway as
  # unavailable until the unit is back, which is what we want.
  systemd.services.hermes-agent.aliases = [ "hermes-gateway.service" ];
  systemd.services.hermes-backend.serviceConfig.ReadWritePaths = [ scratch ];

  # POSIX ACLs, because the vault belongs to diego (Syncthing) and the parents
  # to media. hermes gets traverse on the parents, read on the vault, and
  # read-write on Hermes/. The default entries (d:) cover files Syncthing adds
  # later. diego keeps rwX on Hermes/ so Syncthing can sync what hermes wrote
  # (the unit runs with UMask 0007, so those files are hermes-owned).
  #
  # This is a oneshot the units depend on, not a tmpfiles rule: a unit with
  # ReadWritePaths fails with 226/NAMESPACE when the path is missing, and
  # tmpfiles does not run again when the unit restarts, so it looped forever.
  systemd.services.hermes-vault-access = {
    description = "Create the Hermes scratch folder and set its ACLs in the vault";
    unitConfig.RequiresMountsFor = [ vault ];
    path = [ pkgs.acl pkgs.coreutils pkgs.findutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      setfacl -m u:${cfg.user}:--x /srv/media /srv/media/Obsidian
      install -d -o diego -g users -m 0775 ${scratch}
      setfacl -R -m u:${cfg.user}:rX ${vault}
      find ${vault} -type d -exec setfacl -m d:u:${cfg.user}:rX {} +
      setfacl -R -m u:${cfg.user}:rwX,u:diego:rwX ${scratch}
      find ${scratch} -type d -exec setfacl -m d:u:${cfg.user}:rwX,d:u:diego:rwX {} +
    '';
  };

  # The module copies environmentFiles into .env in an activation script. On
  # this host sops renders secrets later, in sops-install-secrets.service, so
  # that copy always held the previous render (a secret added in one deploy
  # showed up only after the next). EnvironmentFile= reads the rendered file at
  # unit start instead, and restartUnits on the template restarts the units
  # after each render. The .env copy stays as a harmless duplicate.
  systemd.services.hermes-agent = {
    requires = [ "hermes-vault-access.service" ];
    after = [ "hermes-vault-access.service" "sops-install-secrets.service" ];
    wants = [ "sops-install-secrets.service" ];
    serviceConfig.EnvironmentFile = [ config.sops.templates."hermes.env".path ];
  };
  systemd.services.hermes-backend = {
    requires = [ "hermes-vault-access.service" ];
    after = [ "hermes-vault-access.service" "sops-install-secrets.service" ];
    wants = [ "sops-install-secrets.service" ];
    serviceConfig.EnvironmentFile = [ config.sops.templates."hermes.env".path ];
  };
}
  ;
}
