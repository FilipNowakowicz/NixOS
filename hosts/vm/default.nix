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
    ../../modules/nixos/profiles/sops-base.nix
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
      serviceEnvironmentFile = config.sops.templates."otel-env".path;
    };
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
    templates."otel-env" = {
      content = "BASICAUTH_PASSWORD=${config.sops.placeholder.observability_ingest_password}";
      mode = "0400";
    };
    secrets = {
      example_secret = { };
      user_password.neededForUsers = true;
      observability_ingest_password = { };
    };
  };

}
