{
  pkgs,
  lib,
  inputs,
  homeModules,
  customPkgs,
  ...
}:
{
  system.stateVersion = "24.05";

  android-integration = {
    termux-setup-storage.enable = true;
    termux-open-url.enable = true;
  };

  environment.packages = [
    pkgs.llama-cpp-vulkan
    pkgs.curl
    pkgs.jq
    pkgs.git
    pkgs.ripgrep
    pkgs.openssh
  ];

  home-manager.sharedModules = [

    homeModules.colors
  ];

  home-manager.extraSpecialArgs = {
    inherit inputs;
    inherit customPkgs;
    isNixOnDroid = true;
  };

  home-manager.useGlobalPkgs = true;

  home-manager.config =
    { pkgs, lib, ... }:
    let
      serverScript = pkgs.writeShellScriptBin "phone-llm-server" ''
        set -e
        : ''${MODEL_FILE:="$HOME/models/qwen3-8b-instruct-q4_k_m.gguf"}
        : ''${LLM_HOST:="0.0.0.0"}
        : ''${LLM_PORT:="8080"}
        : ''${LLM_CTX:="8192"}
        : ''${LLM_THREADS:="4"}

        if [ ! -f "$MODEL_FILE" ]; then
          echo "model not found: $MODEL_FILE" >&2
          echo "put a GGUF under $HOME/models/ or set MODEL_FILE" >&2
          exit 1
        fi

        exec llama-server \
          -m "$MODEL_FILE" \
          -c "$LLM_CTX" \
          -t "$LLM_THREADS" \
          --host "$LLM_HOST" \
          --port "$LLM_PORT" \
          "$@"
      '';

      sshdScript = pkgs.writeShellScriptBin "phone-sshd" ''
        set -e
        : ''${SSHD_PORT:="8022"}
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        if [ ! -f "$HOME/.ssh/ssh_host_ed25519_key" ]; then
          echo "generating ssh host key..." >&2
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$HOME/.ssh/ssh_host_ed25519_key" -N "" >&2
        fi
        chmod 600 "$HOME/.ssh/ssh_host_ed25519_key"
        exec ${pkgs.openssh}/bin/sshd -D -e -p "$SSHD_PORT" -f "$HOME/.ssh/sshd_config"
      '';

      authorizedKeys = (import ../../parts/_ssh-keys.nix).authorized;
    in
    {
      imports = [
        homeModules.global
        homeModules.cli
      ];

      home.packages = [ serverScript sshdScript ];
      home.stateVersion = "26.05";

      systemd.user.startServices = false;

      home.sessionVariables = {
        LLM_HOST = "0.0.0.0";
        LLM_PORT = "8080";
      };

      programs.bash.enable = true;
      programs.bash.shellAliases = {
        llm-bench-cpu = "llama-bench -m $HOME/models/qwen3-8b-instruct-q4_k_m.gguf -t 4 -p 512 -n 128";
        llm-bench-gpu = "llama-bench -m $HOME/models/qwen3-8b-instruct-q4_k_m.gguf -ngl 99 -p 512 -n 128";
      };

      home.file = {

        ".ssh/authorized_keys".text = (lib.concatStringsSep "\n" authorizedKeys) + "\n";

        ".ssh/sshd_config".text = ''
          Port 8022
          PasswordAuthentication no
          PermitRootLogin no
          PubkeyAuthentication yes
          UsePAM no
          StrictModes no
          AllowUsers nix-on-droid

          HostKey %h/.ssh/ssh_host_ed25519_key
          PidFile %h/.ssh/sshd.pid
          AuthorizedKeysFile %h/.ssh/authorized_keys

          LogLevel VERBOSE
        '';
      };

      programs.ssh = {
        includes = lib.mkForce [ ];
        settings."github.com" = {
          HostName = "ssh.github.com";
          Port = 443;
          IdentityFile = lib.mkForce "~/.ssh/id_ed25519";
        };
      };
    };
}
