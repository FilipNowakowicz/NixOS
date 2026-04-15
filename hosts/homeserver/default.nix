# Placeholder config for a headless home server.
# hardware-configuration.nix must be replaced with real hardware config generated
# on the target machine via: nixos-generate-config
# or during a fresh install via: nixos-anywhere --generate-hardware-config ...
{
  config,
  pkgs,
  inputs,
  ...
}:
let
  network = import ../../lib/network.nix;
  inherit (network) tailnetFQDN;
  syncthing = import ../../lib/syncthing.nix;
  commonSandbox = import ../../lib/sandbox.nix;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/observability.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
  ];

  system.stateVersion = "24.11";

  boot.loader.systemd-boot.configurationLimit = 5;

  networking = {
    hostName = "homeserver";
    useNetworkd = true;
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "yes";
    };
  };

  profiles.observability = {
    enable = true;
    grafana.enable = true;
    grafana.adminPasswordFile = config.sops.secrets.grafana_admin_password.path;
    grafana.secretKeyFile = config.sops.secrets.grafana_secret_key.path;
    loki.enable = true;
    tempo.enable = true;
    mimir.enable = true;
    collectors.metrics.enable = true;
    collectors.logs.enable = true;
    collectors.traces.enable = true;
  };

  # ── Services ────────────────────────────────────────────────────────────────
  # Override the mkDefault false from security.nix — SSH is required on a headless server
  services = {
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

    # Vaultwarden password manager (Bitwarden-compatible server)
    # Accessible via HTTPS reverse proxy at https://homeserver/
    vaultwarden = {
      enable = true;
      config = {
        # Bind to localhost only — nginx reverse proxy handles external access
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;

        # Set to true initially to create your first account, then set to false and redeploy
        SIGNUPS_ALLOWED = false;

        # Use local SQLite database (default, no additional config needed)
        # Database will be at /var/lib/vaultwarden/db.sqlite3

        # Domain used for link generation and API responses — must match how clients access the server
        DOMAIN = "https://${tailnetFQDN}";
      };
    };

    # Syncthing file synchronization
    syncthing = {
      enable = true;
      user = "user";
      dataDir = "/var/lib/syncthing";
      configDir = "/var/lib/syncthing/.config/syncthing";
      openDefaultPorts = true;
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

        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };

        locations."/obs/loki/" = {
          proxyPass = "http://127.0.0.1:3100/";
          basicAuthFile = config.sops.secrets.observability_ingest_htpasswd.path;
        };

        locations."/obs/mimir/" = {
          proxyPass = "http://127.0.0.1:9009/";
          basicAuthFile = config.sops.secrets.observability_ingest_htpasswd.path;
        };

        locations."/obs/otlp/" = {
          proxyPass = "http://127.0.0.1:14318/";
          basicAuthFile = config.sops.secrets.observability_ingest_htpasswd.path;
        };
      };
    };
  };

  # Open firewall for HTTPS
  networking.firewall.allowedTCPPorts = [ 443 ];

  # Fetch certificate from Tailscale (automatic renewal, no self-signed)
  systemd.services.tailscale-cert = {
    description = "Fetch TLS certificate from Tailscale";
    wantedBy = [ "multi-user.target" ];
    after = [
      "tailscaled.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    script = ''
      # Wait for tailscale to be running
      until ${config.services.tailscale.package}/bin/tailscale status --json 2>/dev/null | \
        ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' > /dev/null 2>&1; do
        sleep 5
      done

      # Get the FQDN and request certificate
      mkdir -p /var/lib/tailscale/certs
      ${config.services.tailscale.package}/bin/tailscale cert \
        --cert-file /var/lib/tailscale/certs/homeserver.crt \
        --key-file /var/lib/tailscale/certs/homeserver.key \
        "${tailnetFQDN}"

      # Ensure nginx can read the key
      chmod 640 /var/lib/tailscale/certs/homeserver.key
      chown root:nginx /var/lib/tailscale/certs/homeserver.key

      # Reload nginx to apply new cert
      systemctl reload nginx || true
    '';
    serviceConfig = commonSandbox // {
      Type = "oneshot";
      RemainAfterExit = true;
      ProtectHome = false;
      ReadWritePaths = [ "/var/lib/tailscale" ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };

  # Ensure nginx waits for Tailscale certificate
  systemd.services.nginx = {
    after = [ "tailscale-cert.service" ];
    requires = [ "tailscale-cert.service" ];
    serviceConfig = commonSandbox // {
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      ReadWritePaths = [
        "/var/cache/nginx"
        "/var/log/nginx"
      ];
    };
  };

  systemd.services.vaultwarden.serviceConfig = commonSandbox // {
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ReadWritePaths = [ "/var/lib/vaultwarden" ];
  };

  systemd.services.syncthing.serviceConfig = commonSandbox // {
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ProtectSystem = "full";
    ReadWritePaths = [
      "/var/lib/syncthing"
      "/persist/sync"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/syncthing 0750 user syncthing -"
    "d /var/lib/syncthing/.config 0750 user syncthing -"
    "d /var/lib/syncthing/.config/syncthing 0750 user syncthing -"
    "d /persist/sync 0755 user user -"
    "d /persist/sync/documents 0755 user user -"
    "d /persist/sync/photos 0755 user user -"
  ];

  # ── Sops ────────────────────────────────────────────────────────────────────
  # sops-nix secrets management
  # SSH host key is pre-generated and injected via nixos-anywhere (see scripts/reinstall-homeserver.sh).
  # The host key's age identity is added to .sops.yaml as &homeserver_host before deployment,
  # ensuring the homeserver can decrypt its own secrets (user_password, tailscale_auth_key) from first boot.
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.user_password.neededForUsers = true;
    secrets.tailscale_auth_key = { };
    secrets.grafana_admin_password = { };
    secrets.grafana_secret_key = {
      owner = "grafana";
    };
    secrets.observability_ingest_htpasswd = {
      owner = config.services.nginx.user;
      group = config.services.nginx.group;
    };
    secrets.restic_password = { };
  };

  # ── Backups ──────────────────────────────────────────────────────────────────
  # TODO: replace repository with B2 once bucket is provisioned:
  #   repository = "b2:<bucket-name>:/homeserver";
  #   environmentFile = config.sops.secrets.b2_env.path; # B2_ACCOUNT_ID + B2_ACCOUNT_KEY
  services.restic.backups.local = {
    paths = [
      "/var/lib/vaultwarden"
      "/var/lib/syncthing"
      "/persist/sync"
    ];
    repository = "/persist/restic-repo";
    passwordFile = config.sops.secrets.restic_password.path;
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 3"
    ];
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
    openssh.authorizedKeys.keys = (import ../../lib/pubkeys.nix);
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager = {
    users.user = {
      imports = [ ../../home/users/user/server.nix ];
    };
  };
}
