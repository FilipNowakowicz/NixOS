# Placeholder config for a headless home server.
# hardware-configuration.nix must be replaced with real hardware config generated
# on the target machine via: nixos-generate-config
# or during a fresh install via: nixos-anywhere --generate-hardware-config ...
{
  config,
  pkgs,
  inputs,
  hostMeta,
  ...
}:
let
  inherit (hostMeta) tailnetFQDN;
  syncthing = import ../../lib/syncthing.nix;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/sops-base.nix
    ../../modules/nixos/profiles/user.nix
  ];

  system.stateVersion = "24.11";

  boot.loader.systemd-boot.configurationLimit = 5;

  networking = {
    hostName = "homeserver";
    useNetworkd = true;
  };

  systemd = {
    network = {
      enable = true;
      networks."10-lan" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "yes";
      };
    };

    services = {
      # Fetch certificate from Tailscale (automatic renewal, no self-signed)
      tailscale-cert = {
        description = "Fetch TLS certificate from Tailscale";
        wantedBy = [ "multi-user.target" ];
        after = [
          "tailscaled.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        script = ''
          # Wait for tailscale to be running
          for attempt in {1..60}; do
            ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1 && break
            [ $attempt -lt 60 ] && sleep 1
          done
          ${pkgs.tailscale}/bin/tailscale cert --cert-file /var/lib/tailscale/certs/homeserver.crt --key-file /var/lib/tailscale/certs/homeserver.key ${tailnetFQDN}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 60;
        };
      };

      # Ensure nginx waits for Tailscale certificate
      nginx = {
        after = [ "tailscale-cert.service" ];
        requires = [ "tailscale-cert.service" ];
      };
    };

    tmpfiles.rules = [
      "d /persist/sync 0755 user users -"
      "d /var/lib/syncthing 0700 user users -"
    ];
  };

  profiles.observability = {
    enable = true;
    grafana = {
      enable = true;
      adminPasswordFile = config.sops.secrets.grafana_admin_password.path;
      secretKeyFile = config.sops.secrets.grafana_secret_key.path;
    };
    loki.enable = true;
    tempo.enable = true;
    mimir.enable = true;
    collectors = {
      metrics.enable = true;
      logs.enable = true;
      traces.enable = true;
    };
  };

  # ── Services ────────────────────────────────────────────────────────────────
  # Override the mkDefault false from security.nix — SSH is required on a headless server
  services = {
    hardened = {
      tailscale-cert = {
        extraConfig = {
          ProtectHome = false;
          ReadWritePaths = [ "/var/lib/tailscale" ];
          RestrictAddressFamilies = [ "AF_UNIX" ];
        };
      };

      nginx = {
        extraConfig = {
          CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
          AmbientCapabilities = "CAP_NET_BIND_SERVICE";
          ReadWritePaths = [
            "/var/cache/nginx"
            "/var/log/nginx"
          ];
        };
      };

      vaultwarden = {
        extraConfig = {
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          ReadWritePaths = [ "/var/lib/vaultwarden" ];
        };
      };

      syncthing = {
        extraConfig = {
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          ProtectSystem = "full";
          ProtectHome = false;
          ReadWritePaths = [
            "/home/user"
            "/var/lib/syncthing"
            "/persist/sync"
          ];
        };
      };
    };

    openssh = {
      enable = true;
      openFirewall = true;
    };

    # Tailscale VPN for secure remote access
    tailscale = {
      enable = true;
      openFirewall = true; # Opens UDP port 41641
      authKeyFile = config.sops.secrets.tailscale_auth_key.path;
    };

    # Password manager
    vaultwarden = {
      enable = true;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        SIGNUPS_ALLOWED = false;
        DOMAIN = "https://${tailnetFQDN}";
      };
    };

    # File synchronization
    syncthing = {
      enable = true;
      user = "user";
      dataDir = "/home/user";
      configDir = "/var/lib/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        inherit (syncthing) devices folders;
        gui.address = "127.0.0.1:8384";
        options.urAccepted = -1;
      };
    };

    # ── Nginx ───────────────────────────────────────────────────────────────────
    # Reverse proxy for Vaultwarden
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts.${tailnetFQDN} = {
        forceSSL = true;
        # Tailscale cert provisioning (automatic renewal)
        sslCertificate = "/var/lib/tailscale/certs/homeserver.crt";
        sslCertificateKey = "/var/lib/tailscale/certs/homeserver.key";

        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8222";
            proxyWebsockets = true;
          };

          "/obs/loki/" = {
            proxyPass = "http://127.0.0.1:3100/";
            basicAuthFile = config.sops.secrets.observability_ingest_htpasswd.path;
          };

          "/obs/mimir/" = {
            proxyPass = "http://127.0.0.1:9009/";
            basicAuthFile = config.sops.secrets.observability_ingest_htpasswd.path;
          };

          "/obs/otlp/" = {
            proxyPass = "http://127.0.0.1:14318/";
            basicAuthFile = config.sops.secrets.observability_ingest_htpasswd.path;
          };
        };
      };
    };

    restic.backups.local = {
      paths = [
        "/var/lib/vaultwarden"
        "/var/lib/syncthing"
        "/persist/sync"
      ];
      repository = "/persist/restic-repo";
      passwordFile = config.sops.secrets.restic_password.path;
    };
  };

  # Open firewall for HTTPS
  networking.firewall.allowedTCPPorts = [ 443 ];

  # The host key's age identity is added to .sops.yaml as &homeserver_host before deployment,
  # ensuring the homeserver can decrypt its own secrets (user_password, tailscale_auth_key) from first boot.
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      user_password.neededForUsers = true;
      tailscale_auth_key = { };
      grafana_admin_password = { };
      grafana_secret_key = {
        owner = "grafana";
      };
      observability_ingest_htpasswd = {
        owner = config.services.nginx.user;
        inherit (config.services.nginx) group;
      };
      restic_password = { };
    };
  };

  # ── Impermanence ────────────────────────────────────────────────────────────
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/tailscale" # Persist Tailscale auth state and certs across reboots
      "/var/lib/syncthing" # Persist Syncthing config, database, and synced files
      "/var/lib/vaultwarden" # Persist Vaultwarden database and config
      "/var/lib/grafana"
      "/var/lib/loki"
      "/var/lib/prometheus2"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.user = {
    home = "/home/user";
    hashedPasswordFile = config.sops.secrets.user_password.path;
  };

}
