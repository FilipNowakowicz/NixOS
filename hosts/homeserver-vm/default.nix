# Homeserver config running in a test VM.
# Same services as the real homeserver (Vaultwarden, Syncthing)
# but without Tailscale or cert provisioning.
# Uses nginx with a self-signed cert so the browser accepts HTTPS (required by
# Vaultwarden's web vault). The cert is generated on first boot and persisted.
# Use this to develop and test before hardware arrives.
{ config, pkgs, ... }:
let
  syncthing = import ../../lib/syncthing.nix;
  commonSandbox = import ../../lib/sandbox.nix;
in
{
  imports = [
    ../../modules/nixos/profiles/vm.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/observability.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "homeserver-vm";

  # ── Services ────────────────────────────────────────────────────────────────
  profiles.observability = {
    enable = true;
    grafana.enable = true;
    grafana.secretKeyFile = config.sops.secrets.grafana_secret_key.path;
    loki.enable = true;
    tempo.enable = true;
    mimir.enable = true;
    collectors.metrics.enable = true;
    collectors.logs.enable = true;
    collectors.traces.enable = true;
  };

  services = {
    vaultwarden = {
      enable = true;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        SIGNUPS_ALLOWED = false;
        # nginx proxies HTTPS on 8443 → Vaultwarden on 8222.
        # The DOMAIN must match the URL the browser sees.
        DOMAIN = "https://localhost:8443";
      };
    };

    nginx = {
      enable = true;
      virtualHosts."localhost" = {
        onlySSL = true;
        listen = [
          {
            addr = "127.0.0.1";
            port = 8443;
            ssl = true;
          }
        ];
        # Self-signed cert generated on first boot by vaultwarden-tls-cert.service.
        sslCertificate = "/persist/ssl/cert.pem";
        sslCertificateKey = "/persist/ssl/key.pem";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };
      };
    };

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
  };

  # ── Impermanence (extends vm.nix base) ─────────────────────────────────────
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/syncthing"
    "/var/lib/vaultwarden"
    "/var/lib/grafana"
    "/var/lib/loki"
    "/var/lib/prometheus2"
    "/persist/sync"
  ];

  # Fix permissions on /persist/sync before Syncthing starts.
  systemd.services.vaultwarden.serviceConfig = commonSandbox // {
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ReadWritePaths = [ "/var/lib/vaultwarden" ];
  };

  systemd.services.nginx.serviceConfig = commonSandbox // {
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ReadWritePaths = [
      "/var/cache/nginx"
      "/var/log/nginx"
      "/persist/ssl"
    ];
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

  # Generate a self-signed TLS cert on first boot, stored in /persist so it
  # survives reboots. nginx reads it directly from /persist/ssl/.
  systemd.services.vaultwarden-tls-cert = {
    description = "Generate self-signed TLS cert for Vaultwarden (dev VM only)";
    wantedBy = [ "nginx.service" ];
    before = [ "nginx.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = commonSandbox // {
      Type = "oneshot";
      RemainAfterExit = true;
      ProtectHome = false;
      ReadWritePaths = [ "/persist" ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
    script = ''
      mkdir -p /persist/ssl

      if [ ! -f /persist/ssl/cert.pem ] || [ ! -f /persist/ssl/key.pem ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 \
          -keyout /persist/ssl/key.pem \
          -out /persist/ssl/cert.pem \
          -days 3650 -nodes -subj '/CN=localhost'
      fi

      chown root:nginx /persist/ssl/key.pem /persist/ssl/cert.pem
      chmod 750 /persist/ssl
      chmod 640 /persist/ssl/key.pem
      chmod 644 /persist/ssl/cert.pem
    '';
  };

  # Syncthing requires this tree to exist and be writable on first boot.
  systemd.tmpfiles.rules = [
    "d /persist 0755 root root -"
    "d /persist/ssl 0750 root nginx -"
    "d /var/lib/syncthing 0750 user syncthing -"
    "d /var/lib/syncthing/.config 0750 user syncthing -"
    "d /var/lib/syncthing/.config/syncthing 0750 user syncthing -"
    "d /persist/sync 0755 user user -"
    "d /persist/sync/documents 0755 user user -"
    "d /persist/sync/photos 0755 user user -"
  ];

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.user = {
    home = "/home/user";
    extraGroups = [
      "video"
      "wheel"
    ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = import ../../lib/pubkeys.nix;
  };

  # ── Sops ────────────────────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets.user_password.neededForUsers = true;
    secrets.restic_password = { };
    secrets.grafana_secret_key = {
      owner = "grafana";
    };
  };

  # ── Backups ──────────────────────────────────────────────────────────────────
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

  # Support SSH sessions from Kitty terminals (`TERM=xterm-kitty`).
  environment.systemPackages = [ pkgs.kitty.terminfo ];

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager.users.user.imports = [ ../../home/users/user/server.nix ];
}
