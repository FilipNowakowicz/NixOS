{
  config,
  pkgs,
  hostMeta,
  ...
}:
let
  syncthing = import ../../lib/syncthing.nix;
in
{
  imports = [
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/sops-base.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/microvm-guest.nix
  ];

  networking.hostName = "homeserver-vm";
  system.stateVersion = "24.11";

  systemd.network.networks."20-eth" = {
    matchConfig.MACAddress = "02:00:00:00:00:01";
    networkConfig = {
      Address = "${hostMeta.ip}/24";
      Gateway = "10.0.100.1";
      DNS = "1.1.1.1";
    };
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    vsock.cid = 3;

    # Share host's Nix store via virtiofs — avoids building a slow erofs image.
    storeOnDisk = false;

    interfaces = [
      {
        type = "tap";
        id = "vm-homeserver";
        mac = "02:00:00:00:00:01";
      }
    ];

    volumes = [
      {
        image = "persist.img";
        mountPoint = "/persist";
        size = 10240;
        fsType = "ext4";
        label = "persist";
        autoCreate = true;
      }
    ];

    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
      }
      {
        tag = "age-keys";
        source = "/run/microvms/homeserver-vm/age-keys";
        mountPoint = "/run/age-keys";
        proto = "virtiofs";
      }
    ];
  };

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
    dashboards.fleet.enable = true;
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

  services.hardened = {
    vaultwarden = {
      extraConfig = {
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ReadWritePaths = [ "/var/lib/vaultwarden" ];
      };
    };

    nginx = {
      extraConfig = {
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ReadWritePaths = [
          "/persist/nginx"
          "/var/cache/nginx"
          "/var/log/nginx"
        ];
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

  systemd = {
    services = {
      nginx-selfsigned = {
        description = "Generate self-signed certificate for nginx";
        wantedBy = [ "multi-user.target" ];
        before = [ "nginx.service" ];
        unitConfig.ConditionPathExists = "!/persist/nginx/cert.pem";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -keyout /persist/nginx/key.pem -out /persist/nginx/cert.pem -sha256 -days 3650 -nodes -subj '/CN=localhost'";
          ExecStartPost = "${pkgs.coreutils}/bin/chown nginx:nginx /persist/nginx/key.pem /persist/nginx/cert.pem";
        };
      };
    };

    tmpfiles.rules = [
      "d /persist/nginx 0700 nginx nginx -"
      "d /persist/sync 0755 user users -"
      "d /var/lib/syncthing 0700 user users -"
    ];
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/run/age-keys/homeserver-vm.txt";
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
  };

  # ── Impermanence ────────────────────────────────────────────────────────────
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist".directories = [
    "/var/lib/syncthing"
    "/var/lib/vaultwarden"
    "/var/lib/grafana"
    "/var/lib/loki"
    "/var/lib/mimir"
    "/var/lib/prometheus2"
    "/var/lib/tempo"
  ];

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.user = {
    home = "/home/user";
    hashedPasswordFile = config.sops.secrets.user_password.path;
  };

}
