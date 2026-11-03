{ config, ... }:
{
  flake.modules.homeManager.cli =
{
  pkgs,
  lib,
  customPkgs ? {},
  isNixOnDroid ? false,
  ...
}:
let

  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isAndroid = isNixOnDroid || pkgs.stdenv.hostPlatform.isAndroid or false;
  isDesktop = isLinux && !isAndroid;
in
{
  imports = with config.flake.modules.homeManager; [ cli-zoxide cli-helix cli-pfetch cli-git cli-xdg cli-starship cli-fzf cli-bat cli-zellij cli-nushell cli-herdr cli-ssh cli-bottom cli-superfile cli-teams-calls-fetch ];

  home.packages =
    with pkgs;

    [
      timr-tui
      basalt
      comma
      fd
      fzf
      jq
      nixfmt
      ouch
      pv
      ripgrep
      sqlite
      wget
      zip
      cursor-cli
    ]

    ++ lib.optionals (isDesktop || isDarwin) [
      gh
      broot
      uv
      gping
      stow
      codex
      teleport
      scope-tui
      antigravity-cli
      herdr

      llm
      claude-monitor
    ]

    ++ lib.optionals (isDesktop || isDarwin) [
      cursor-cli
      claude-code
    ]

    ++ lib.optionals (isLinux && !isAndroid) [
      deploy-rs
    ]
    ++ lib.optionals isDesktop [
      customPkgs.device-mount
      customPkgs.device-umount
    ]
    ++ lib.optionals (customPkgs ? teams-calls-fetcher) [
      customPkgs.teams-calls-fetcher
    ];
}
;
}
