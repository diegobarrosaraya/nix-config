# nix-config

Public flake for Diego's machines: cobalto (server), rubi (desktop), jade (nix-on-droid). It uses flake-parts
with the dendritic pattern. This file is the source of truth for coding agents. Read it before you change anything.

## Layout

- `flake.nix`: inputs. `parts/*.nix`: flake-parts modules (`hosts/`, `homes.nix`, `deploy.nix`, `packages.nix`, `overlays.nix`).
- `parts/hosts/<host>.nix`: builds `nixosConfigurations.<host>` from `flake.modules.nixos.*`.
- `parts/nixos/global/`: modules every NixOS host gets.
- `parts/nixos/optional/<area>/<name>.nix`: opt-in modules. Each file defines `flake.modules.nixos.<area>-<name>`.
  A host turns one on by listing its name in `parts/nixos/hosts/<host>/default.nix`.
- `parts/nixos/hosts/<host>/`: host config, including `impermanence.nix` for cobalto and rubi.
- `parts/home/`: home-manager. `features/{ai,audio,cli,desktop}/` hold the modules, `<host>.nix` selects them.
- `docs/`: runbooks. `docs/superpowers/{specs,plans}/`: specs and plans written by coding agents.
  `docs/agents/dev-rules.md`: rules given to Hermes-launched agents.

## Conventions

- Follow the pattern of the file next to the one you edit. Do not add `hosts/common/` or `modules/home-manager/`: they do not exist here.
- A new optional module is one file under `parts/nixos/optional/<area>/`, named like its neighbours, and enabled by name in the host.
  Use `lib.mkEnableOption` only where the neighbouring modules already use options. Many modules here are plain on/off by import.
- Flakes see only tracked files. Run `git add` on new files before any `nix` command.
- Comments explain why, not what. Keep the style of the surrounding file.
- Anything that holds state on cobalto or rubi (impermanence) needs its path in that host's `impermanence.nix`.

## Three repos

- This repo is public. It must not name customers or hold secrets.
- `nix-ai-tooling` (input `ai-tooling`): generic modules for Claude, opencode and the like.
- `nix-private-config` (input `private-config`): customer data, accounts, work secrets. Do not copy its content here.

## Checks

- `nix flake check --no-build` before you say a change is done.
- For a change to a host, also build it: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.

## Deploy (Diego does this, agents do not)

- cobalto: `deploy .#cobalto` (deploy-rs, defined in `parts/deploy.nix`). It builds on cobalto and connects as root to the host `cobalto` over Tailscale. Rollback is off (`magicRollback` and `autoRollback` are false).
- A failed unit during activation rolls back the whole deploy, even if the unit is unrelated.
- Do not move the `nixpkgs` pin on cobalto. It must match the Jellyfin database. Add a second pin for a newer package (see `nixpkgs-acp`).
- This repo has no workflows: its Actions logs would be public. The CI deploy lives in the private repo (`nix-private-config`, workflow `deploy-cobalto`).
  Diego starts it with `gh workflow run deploy-cobalto.yml -R DiegoBarrosA/nix-private-config`, so a merge to `main` does not deploy by itself.
  It does not wait for Hermes. A deploy restarts Hermes, so a task running at that moment loses its current step: resume it with `--resume`.
- Do not add `.github/workflows/` here. If a check is needed, run it in the private repo.

## Hermes

- Hermes runs on cobalto (`parts/nixos/optional/ai/hermes-agent.nix`). It only dispatches coding agents (Kanban cards and `claude-<name>` runs). It never edits this repo.
- Coder profiles edit in worktrees on a branch and commit locally. Among the Kanban role profiles only `integrator` pushes and opens PRs (Hermes chat and the temporary `coder` profile can still push). Diego merges and deploys.
