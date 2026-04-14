# Homeserver config running in a test VM.
# Same services as the real homeserver (Vaultwarden, Syncthing)
# but without Tailscale, Nginx, or cert provisioning.
# Use this to develop and test before hardware arrives.
{
  config,
  pkgs,
  inputs,
  ...
}:
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

  boot.loader.systemd-boot.configurationLimit = 5;

  nix.settings.trusted-users = [
    "root"
    "user"
  ];

  # ── Networking ──────────────────────────────────────────────────────────────
  networking = {
    hostName = "homeserver-vm";
    networkmanager.enable = true;
  };

  # ── SSH ─────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # ── Services ────────────────────────────────────────────────────────────────
  services = {
    # Vaultwarden password manager (test config — Tailscale/Nginx not available in VM)
    vaultwarden = {
      enable = true;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        SIGNUPS_ALLOWED = false;
        DOMAIN = "http://127.0.0.1:8222";
      };
    };

    # Syncthing file synchronization
    syncthing = {
      enable = true;
      user = "user";
      dataDir = "/var/lib/syncthing";
      configDir = "/var/lib/syncthing/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = false;
      overrideFolders = false;
      settings = {
        gui = {
          address = "127.0.0.1:8384";
        };
        options = {
          urAccepted = -1;
        };
      };
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
      "/var/lib/syncthing" # Persist Syncthing config and synced files
      "/var/lib/vaultwarden" # Persist Vaultwarden database
      "/etc/NetworkManager/system-connections"
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
    extraGroups = [ "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = (import ../../lib/pubkeys.nix);
  };

  # ── Sops ────────────────────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.example_secret = { };
    secrets.user_password.neededForUsers = true;
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager = {
    users.user = {
      imports = [ ../../home/users/user/home.nix ];
    };
  };
}
