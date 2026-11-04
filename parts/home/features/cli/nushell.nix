{ ... }:
{
  flake.modules.homeManager.cli-nushell =
{ pkgs, config, ... }:
{
  programs.nushell = {
    enable = true;
    # keep pre-26.11 behaviour; silences the stateVersion default-change warning
    loadSessionVariables = false;

    shellAliases = {

      top = "btm";
      jqless = "jq -C | less -r";
      n = "nix";
      nd = "nix develop -c $env.SHELL";
      ns = "nix shell";
      nsn = "nix shell nixpkgs#";
      nb = "nix build";
      nbn = "nix build nixpkgs#";
      nf = "nix flake";
      nr = "nixos-rebuild --flake .";
      nrs = "nixos-rebuild --flake . switch";
      snr = "sudo nixos-rebuild --flake .";
      snrs = "sudo nixos-rebuild --flake . switch";
      hm = "home-manager --flake .";
      hms = ''home-manager switch -b $"backup_(date now | format date '%Y-%m-%d_%H-%M-%S')" --flake .'';
      v = "hx";
      vi = "hx";
      vim = "hx";
      l = "ls";
      lk = "ls";
      ll = "ls";
      cat = "bat";

      getip = "curl ifconfig.me";
      kssh = "kitty +kitten ssh";

      zj = "zellij";

      dev = "zellij --layout dev";

      hd = "herdr";
      # ponytail: toad isn't in nixpkgs yet, uvx runs the latest PyPI release on demand
      toad = "uvx --from batrachian-toad toad";
    };

    extraEnv = ''
      def --env source-bash-env [file: string] {
        if ($file | path exists) {
          bash -c $"source ($file) && env"
            | lines
            | where { |line| $line =~ "=" }
            | parse "{key}={value}"
            | where { |it| $it.key not-in ["_", "SHLVL", "PWD", "FILE_PWD", "CURRENT_FILE"] }
            | transpose -r -d
            | load-env
        }
      }

      source-bash-env /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

      source-bash-env $"($env.HOME)/.nix-profile/etc/profile.d/hm-session-vars.sh"

      $env.PATH = ($env.PATH | split row (char esep)
        | prepend $"($env.HOME)/.nix-profile/bin"
        | prepend "/nix/var/nix/profiles/default/bin"
        | uniq)

      try { source "${config.home.homeDirectory}/.config/nushell/mcp-env.nu" }

      $env.config = ($env.config? | default {} | merge {
        hooks: {
          pre_prompt: [{
            if "GHOSTY_RESOURCES_DIR" in $env {
              print -n $"\e]7;file://($env.HOSTNAME? | default 'localhost')($env.PWD)\e\\"
            }
          }]
        }
      })
    '';

    extraConfig = ''
      $env.PROMPT_INDICATOR = ""
      $env.EDITOR = "hx"
      $env.PROMPT_INDICATOR_VI_INSERT = ""
      $env.PROMPT_INDICATOR_VI_NORMAL = ""

      $env.config.edit_mode = "vi"

      $env.config.keybindings = ($env.config.keybindings? | default [] | append [
        {
          name: launch_zellij
          modifier: control
          keycode: char_t
          mode: [vi_insert vi_normal emacs]
          event: { send: executehostcommand cmd: "zellij" }
        }
        {
          name: edit_command
          modifier: alt
          keycode: char_e
          mode: [vi_insert vi_normal emacs]
          event: { send: openeditor }
        }
      ])

      def wh [cmd: string] {
        which $cmd | get path.0 | path expand
      }

      def tz [path: string] {
        tar -acf $"($path).tar.zst" $path
      }

      $env.config.show_banner = false
    '';
  };

  home.shellAliases = {
    moe = "iina https://listen.moe/stream";
  };
}
;
}
