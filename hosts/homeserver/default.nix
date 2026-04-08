# Placeholder config for a headless home server.
# hardware-configuration.nix must be replaced with real hardware config generated
# on the target machine via: nixos-generate-config
# or during a fresh install via: nixos-anywhere --generate-hardware-config ...
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/server.nix
  ];

  system.stateVersion = "24.11";

  networking = {
    hostName = "homeserver";
    networkmanager.enable = true;
  };

  # Override the mkDefault false from security.nix — SSH is required on a headless server
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # Tailscale VPN for secure remote access
  services.tailscale = {
    enable = true;
    openFirewall = true;  # Opens UDP port 41641
    authKeyFile = config.sops.secrets.tailscale_auth_key.path;
  };

  # Vaultwarden password manager (Bitwarden-compatible server)
  # Accessible via HTTPS reverse proxy at https://homeserver/
  services.vaultwarden = {
    enable = true;
    config = {
      # Bind to localhost only — nginx reverse proxy handles external access
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      # Disable new signups after first user registers
      # Set to false initially to create your account, then change to true
      SIGNUPS_ALLOWED = false;

      # Use local SQLite database (default, no additional config needed)
      # Database will be at /var/lib/vaultwarden/db.sqlite3

      # Domain for web vault and API
      # Update this to your actual domain when using real certs
      DOMAIN = "https://homeserver";
    };
  };

  # Syncthing file synchronization
  # Web UI accessible at http://homeserver:8384/
  services.syncthing = {
    enable = true;
    user = "user";
    dataDir = "/var/lib/syncthing";  # Sync folder base directory
    configDir = "/var/lib/syncthing/.config/syncthing";  # Config and database
    openDefaultPorts = true;  # Opens TCP 22000, UDP 22000, TCP 21027, UDP 21027
    overrideDevices = true;  # Allow declarative device configuration
    overrideFolders = true;  # Allow declarative folder configuration
    settings = {
      options = {
        urAccepted = -1;  # Disable usage reporting
      };
    };
  };

  # Nginx reverse proxy for Vaultwarden
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."homeserver" = {
      forceSSL = true;
      # Self-signed certificate for now
      # TODO: Replace with ACME/Let's Encrypt for production:
      #   enableACME = true;
      #   acmeRoot = null;  # Use HTTP-01 challenge
      # And add: security.acme.acceptTerms = true;
      #          security.acme.defaults.email = "your@email.com";
      sslCertificate = "/var/lib/nginx/cert.pem";
      sslCertificateKey = "/var/lib/nginx/key.pem";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8222";
        proxyWebsockets = true;
      };
    };
  };

  # Open firewall for HTTPS
  networking.firewall.allowedTCPPorts = [ 443 ];

  # Generate self-signed certificate for nginx
  # This is a placeholder until ACME is configured
  systemd.services.nginx-cert = {
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
    script = ''
      mkdir -p /var/lib/nginx
      if [ ! -f /var/lib/nginx/cert.pem ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -nodes -newkey rsa:4096 \
          -keyout /var/lib/nginx/key.pem \
          -out /var/lib/nginx/cert.pem \
          -days 365 -subj "/CN=homeserver"
        chmod 600 /var/lib/nginx/key.pem
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # sops-nix secrets management
  # Currently encrypted only to user age key. After first deploy, the SSH host key
  # will be extracted, converted to age (ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub),
  # added to .sops.yaml as &homeserver_host, and secrets re-encrypted to include it.
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.user_password = {};
    secrets.tailscale_auth_key = {};
  };

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/tailscale"  # Persist Tailscale auth state across reboots
      "/var/lib/syncthing"  # Persist Syncthing config, database, and synced files
      "/var/lib/vaultwarden"  # Persist Vaultwarden database and config
      "/var/lib/nginx"  # Persist nginx self-signed certs
      "/var/lib/acme"  # Persist ACME/Let's Encrypt certs (for future use)
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  users.users.user = {
    home = "/home/user";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC31z32AcISdGR5ng15HNHmOPPmzPkX+KRQzr98Xhlze"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.user = {
      imports = [ ../../home/users/user/home-server.nix ];
    };
  };
}
