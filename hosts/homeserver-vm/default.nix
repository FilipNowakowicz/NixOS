# Homeserver config running in a test VM.
# Same services as the real homeserver (Vaultwarden, Syncthing)
# but without Tailscale, Nginx, or cert provisioning.
# Use this to develop and test before hardware arrives.
{ config, ... }:
{
  imports = [
    ../../modules/nixos/profiles/vm.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/server.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "homeserver-vm";

  # ── Services ────────────────────────────────────────────────────────────────
  services = {
    vaultwarden = {
      enable = true;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        SIGNUPS_ALLOWED = false;
        DOMAIN = "http://127.0.0.1:8222";
      };
    };

    syncthing = {
      enable = true;
      user = "user";
      dataDir = "/var/lib/syncthing";
      configDir = "/var/lib/syncthing/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = false;
      overrideFolders = false;
      settings = {
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
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager.users.user.imports = [ ../../home/users/user/home-server.nix ];
}
