{ ... }:
{
  flake.modules.nixos.network-minerales-network =
{
  config,
  lib,
  pkgs,
  ...
}:

let

  withSSL =
    domain: vhostConfig:
    vhostConfig
    // {
      forceSSL = true;
      useACMEHost = "minerales.network";
    };

  standardProxy = port: {
    proxyPass = "http://127.0.0.1:${toString port}";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_buffering off;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-Host $host;
    '';
  };
in
{

  systemd.tmpfiles.rules = [
    "d /var/lib/private 0700 root root -"
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "diego@minerales.network";

    # Resolve DNS-01 challenges against a public resolver instead of the system
    # one. /etc/resolv.conf points at Tailscale MagicDNS (100.100.100.100),
    # which answers REFUSED for SOA lookups on non-tailnet domains, so lego
    # could not find the Cloudflare zone and fell back to self-signed certs.
    defaults.dnsResolver = "1.1.1.1:53";

    certs."minerales.network" = {
      domain = "minerales.network";
      extraDomainNames = [ "*.minerales.network" ];
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialFiles = {
        "CF_DNS_API_TOKEN_FILE" = config.sops.secrets."cloudflare-dns-token".path;
      };

      reloadServices = [ "nginx" ];
    };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  services.nginx = {
    enable = true;

    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    proxyTimeout = "300s";

    clientMaxBodySize = "1g";

    virtualHosts = {

      "_" = {
        forceSSL = true;
        useACMEHost = "minerales.network";
        serverName = "_";
        extraConfig = ''
          ssl_reject_handshake on;
        '';
      };

      "home.minerales.network" = withSSL "home" {
        locations."/" = standardProxy 8082;

        locations."/zennotes-icon.svg" = {
          root = ../../../../assets/homepage;
        };
      };

      "jellyfin.minerales.network" = withSSL "jellyfin" {
        locations."/" = standardProxy 8096;
      };

      "transmission.minerales.network" = withSSL "transmission" {
        locations."/" = {
          proxyPass = "http://localhost:8080";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Transmission-Session-Id $http_x_transmission_session_id;
            proxy_pass_header X-Transmission-Session-Id;
          '';
        };
      };

      "bookorbit.minerales.network" = withSSL "bookorbit" {
        locations."/" = standardProxy 8090;
      };

      "jellyseerr.minerales.network" = withSSL "jellyseerr" {
        locations."/" = standardProxy 5055;
      };

      "tdarr.minerales.network" = withSSL "tdarr" {
        locations."/" = standardProxy 8265;
      };

      "aria2.minerales.network" = withSSL "aria2" {
        locations."/" = standardProxy 6800;
        locations."/jsonrpc" = standardProxy 6800;
      };

      "prowlarr.minerales.network" = withSSL "prowlarr" {
        locations."/" = standardProxy 9696;
      };

      "flaresolverr.minerales.network" = withSSL "flaresolverr" {
        locations."/" = standardProxy 8191;
      };

      "sonarr.minerales.network" = withSSL "sonarr" {
        locations."/" = standardProxy 8989;
      };

      "radarr.minerales.network" = withSSL "radarr" {
        locations."/" = {
          proxyPass = "http://localhost:7878/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

      "lidarr.minerales.network" = withSSL "lidarr" {
        locations."/" = standardProxy 8686;
      };

      "bazarr.minerales.network" = withSSL "bazarr" {
        locations."/" = standardProxy 6767;
      };

      "syncthing.minerales.network" = withSSL "syncthing" {
        locations."/" = {
          proxyPass = "http://localhost:8384";
          proxyWebsockets = true;
          extraConfig = "proxy_buffering off;";
        };
      };

      "cockpit.minerales.network" = withSSL "cockpit" {
        locations."/" = {
          proxyPass = "https://localhost:9090";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

      "portainer.minerales.network" = withSSL "portainer" {
        locations."/" = standardProxy 8098;
      };

      "llm.minerales.network" = withSSL "llm" {
        locations = {

          "/v1/" = {
            proxyPass = "http://localhost:11435/v1/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              proxy_read_timeout 600s;  # Long timeout for LLM generation
            '';
          };
        };
      };

      "llama.minerales.network" = withSSL "llama" {
        locations."/" = {
          proxyPass = "http://localhost:11435";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout 600s;  # Long timeout for LLM generation
          '';
        };
      };

      "jupyter.minerales.network" = withSSL "jupyter" {
        locations."/" = standardProxy 8888;
      };

      "sync.minerales.network" = withSSL "sync" {
        locations."/" = {
          proxyPass = "http://localhost:5984";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout 600s;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

      "homeassistant.minerales.network" = withSSL "homeassistant" {
        locations."/" = {
          proxyPass = "http://localhost:8123";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

      "ma.minerales.network" = withSSL "ma" {
        locations."/" = {
          proxyPass = "http://localhost:8095";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

      "snapcast.minerales.network" = withSSL "snapcast" {
        root = "${pkgs.snapweb}";
        locations = {
          "/" = {
            tryFiles = "$uri $uri/ /index.html";
            index = "index.html";
          };
          "/jsonrpc" = {
            proxyPass = "http://localhost:1780";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host;
            '';
          };
        };
      };

      "opencode.minerales.network" = withSSL "opencode" {
        locations."/" = standardProxy 4096;
      };

      # Agent with shell access: LAN and tailnet only, on top of the dashboard
      # login. Ports 80/443 are open on the firewall, so do not rely on DNS.
      "hermes.minerales.network" = withSSL "hermes" {
        locations."/" = (standardProxy 9119) // {
          extraConfig = ''
            allow 192.168.0.0/16;
            allow 10.0.0.0/8;
            allow 100.64.0.0/10;
            allow 127.0.0.1;
            deny all;
            proxy_buffering off;
            proxy_read_timeout 3600s;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

      "notes.minerales.network" = withSSL "notes" {
        locations."/" = standardProxy 7879;
      };

      "yattee.minerales.network" = withSSL "yattee" {
        locations."/" = standardProxy 8085;
      };

      "turn.minerales.network" = withSSL "turn" {
        locations."/" = {
          extraConfig = ''
            default_type text/html;
            return 200 '<html><body><h1>TURN Server</h1><p>This is a TURN/STUN server for voice/video calls.</p></body></html>';
          '';
        };
      };

      "vault.minerales.network" = withSSL "vault" {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
    trustedInterfaces = [ "tailscale0" ];
    extraCommands = ''
      iptables -I nixos-fw -i tailscale0 -j nixos-fw-accept
    '';
  };

  services.nginx.appendHttpConfig = ''
    set_real_ip_from 100.64.0.0/10;
    real_ip_header X-Forwarded-For;
  '';

  services.nginx.serverTokens = false;
}
  ;
}
