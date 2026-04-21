{
  config,
  pkgs,
  inputs,
  ...
}:
let
  syncthing = import ../../lib/syncthing.nix;
  commonSandbox = import ../../lib/sandbox.nix;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disko.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/observability.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/vm.nix
  ];

  networking.hostName = "homeserver-vm";

  profiles.observability = {
    enable = true;
    # vm hosts the full stack for testing
    grafana.enable = true;
    grafana.secretKeyFile = config.sops.secrets.grafana_secret_key.path;
    loki.enable = true;
    tempo.enable = true;
    mimir.enable = true;
    collectors = {
      metrics.enable = true;
      logs.enable = true;
      traces.enable = true;
    };
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
        sslCertificate = "/persist/nginx/cert.pem";
        sslCertificateKey = "/persist/nginx/key.pem";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };
      };
    };

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
  };

  systemd = {
    services = {
      vaultwarden.serviceConfig = commonSandbox // {
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ReadWritePaths = [ "/var/lib/vaultwarden" ];
      };

      nginx.serviceConfig = commonSandbox // {
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ReadWritePaths = [
          "/persist/nginx"
          "/var/cache/nginx"
          "/var/log/nginx"
        ];
      };

      syncthing.serviceConfig = commonSandbox // {
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ProtectSystem = "full";
        ReadWritePaths = [
          "/var/lib/syncthing"
          "/persist/sync"
        ];
      };

      nginx-selfsigned = {
        description = "Generate self-signed certificate for nginx";
        wantedBy = [ "multi-user.target" ];
        before = [ "nginx.service" ];
        conditionPathExists = "!/persist/nginx/cert.pem";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -keyout /persist/nginx/key.pem -out /persist/nginx/cert.pem -sha256 -days 3650 -nodes -subj '/CN=localhost'";
          ExecStartPost = "${pkgs.coreutils}/bin/chown nginx:nginx /persist/nginx/key.pem /persist/nginx/cert.pem";
        };
      };
    };

    tmpfiles.rules = [
      "d /persist/nginx 0700 nginx nginx -"
    ];
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      user_password.neededForUsers = true;
      restic_password = { };
      grafana_secret_key = {
        owner = "grafana";
      };
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

  # ── Impermanence ────────────────────────────────────────────────────────────
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/syncthing"
      "/var/lib/vaultwarden"
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
    openssh.authorizedKeys.keys = import ../../lib/pubkeys.nix;
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager = {
    users.user = {
      imports = [ ../../home/users/user/server.nix ];
    };
  };
}
