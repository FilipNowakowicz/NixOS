{ config, hostRegistry, ... }:
{
  imports = [
    ../../modules/nixos/profiles/vm.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/observability-client.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/sops-base.nix
    ../../modules/nixos/profiles/user.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "vm";

  # ── Impermanence (extends vm.nix base) ─────────────────────────────────────
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
  ];

  profiles.observability-client = {
    enable = true;
    remoteEndpoint.host = hostRegistry.homeserver.tailnetFQDN;
  };

  # ── Systemd Failure Notifications ──────────────────────────────────────────
  services.systemd-failure-notify = {
    enable = true;
    services = [ "NetworkManager" ];
  };

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.user = {
    home = "/home/user";
    extraGroups = [ "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
  };

  # ── Sops ────────────────────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      example_secret = { };
      user_password.neededForUsers = true;
      observability_ingest_password = { };
    };
  };

}
