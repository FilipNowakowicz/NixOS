{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/server.nix
  ];

  system.stateVersion = "24.11";

  boot.loader.systemd-boot.configurationLimit = 5;

  # ── Networking ──────────────────────────────────────────────────────────────
  networking = {
    hostName = "vm";
    networkmanager.enable = true;
  };

  # ── SSH ─────────────────────────────────────────────────────────────────────
  # Enable SSH for remote deployment via `ssh nixvm`
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # ── Impermanence ────────────────────────────────────────────────────────────
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
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
    openssh.authorizedKeys.keys = (import ../../lib/pubkeys.nix);
  };

  # ── Sops ────────────────────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.example_secret = { };
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager = {
    users.user = {
      imports = [ ../../home/users/user/home.nix ];
    };
  };
}
