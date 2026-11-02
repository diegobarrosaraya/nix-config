{ ... }:
{
  flake.modules.homeManager.cli-ssh =
{
  config,
  lib,
  pkgs,
  isNixOnDroid ? false,
  ...
}:
let
  inherit (lib) concatStringsSep mapAttrsToList mkIf;

  keys = {
    diego = "~/.ssh/keys/id_ed25519";
    git = "~/.ssh/keys/git_ed25519";
    work = "~/.ssh/keys/work_ed25519";
  };

  hasSystemd = pkgs.stdenv.hostPlatform.isLinux && !(isNixOnDroid || pkgs.stdenv.hostPlatform.isAndroid or false);

  addAllScript = pkgs.writeShellScript "ssh-add-all" (
    concatStringsSep "\n" (
      mapAttrsToList (name: path: ''
        ${pkgs.openssh}/bin/ssh-add ${path} >/dev/null 2>&1 || true
      '') keys
    )
  );
in
{
  programs.ssh = {
    enable = true;

    includes = [ "~/.ssh/omnistation-config" ];

    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        IdentitiesOnly = true;
      };

      cobalto = {
        HostName = "100.69.115.53";
        IdentityFile = keys.diego;
      };
      "rubi *.mineral.network" = {
        IdentityFile = keys.diego;
      };

      jade = {
        HostName = "192.168.1.36";
        Port = 8022;
        User = "nix-on-droid";
        IdentityFile = keys.diego;
      };
      jade-usb = {
        HostName = "127.0.0.1";
        Port = 8022;
        User = "nix-on-droid";
        IdentityFile = keys.diego;
      };

      "github.com" = {
        User = "git";
        IdentityFile = keys.git;
      };

      "bitbucket.org" = {
        IdentityFile = keys.work;
      };

      "*.teleport.sh" = {
        IdentityFile = keys.work;
      };

      amatista = {
        HostName = "146.235.245.77";
        User = "opc";
        IdentityFile = keys.diego;
      };
      azabache = {
        HostName = "146.181.58.241";
        User = "opc";
        IdentityFile = keys.diego;
      };
    };
  };

  services.ssh-agent.enable = true;

  systemd.user.services.ssh-add = mkIf hasSystemd {
    Unit = {
      Description = "Register SSH keys into the agent at login";
      After = [ "ssh-agent.service" ];
      Requires = [ "ssh-agent.service" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent";
      ExecStart = addAllScript;
    };
  };

  launchd.agents.ssh-add = mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      RunAtLoad = true;
      ProgramArguments = [ (toString addAllScript) ];
    };
  };

  programs.nushell.extraConfig = ''
    def ssh-add-all [] {
    ${concatStringsSep "\n" (mapAttrsToList (name: path: "    ssh-add ${path}") keys)}
    }
  '';
}
;
}
