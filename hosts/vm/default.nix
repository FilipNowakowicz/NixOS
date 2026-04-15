{ config, ... }:
let
  network = import ../../lib/network.nix;
  inherit (network) tailnetFQDN;
in
{
  imports = [
    ../../modules/nixos/profiles/vm.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/observability.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "vm";

  # ── Impermanence (extends vm.nix base) ─────────────────────────────────────
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
  ];

  profiles.observability = {
    enable = true;
    collectors = {
      metrics = {
        enable = true;
        remoteWriteURL = "https://${tailnetFQDN}/obs/mimir/api/v1/push";
      };
      logs = {
        enable = true;
        pushURL = "https://${tailnetFQDN}/obs/loki/loki/api/v1/push";
      };
      traces = {
        enable = true;
        exportURL = "https://${tailnetFQDN}/obs/otlp";
      };
    };
    ingestAuth = {
      username = "telemetry";
      passwordFile = config.sops.secrets.observability_ingest_password.path;
    };
  };

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.user = {
    home = "/home/user";
    extraGroups = [ "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = import ../../lib/pubkeys.nix;
  };

  # ── Sops ────────────────────────────────────────────────────────────────────
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets.example_secret = { };
    secrets.user_password.neededForUsers = true;
    secrets.observability_ingest_password = { };
  };

  # ── Home Manager ────────────────────────────────────────────────────────────
  home-manager.users.user.imports = [ ../../home/users/user/home.nix ];
}
