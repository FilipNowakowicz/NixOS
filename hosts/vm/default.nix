{ config, ... }:
{
  imports = [
    ../../modules/nixos/profiles/vm.nix
    ../../modules/nixos/profiles/base.nix
    ../../modules/nixos/profiles/desktop.nix
    ../../modules/nixos/profiles/observability.nix
    ../../modules/nixos/profiles/security.nix
    ../../modules/nixos/profiles/user.nix
    ../../modules/nixos/profiles/server.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "vm";

  # ── Impermanence (extends vm.nix base) ─────────────────────────────────────
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
  ];

  profiles.observability = {
    enable = true;
    collectors.metrics.enable = true;
    collectors.metrics.remoteWriteURL = "https://homeserver.filip-nowakowicz.ts.net/obs/mimir/api/v1/push";
    collectors.logs.enable = true;
    collectors.logs.pushURL = "https://homeserver.filip-nowakowicz.ts.net/obs/loki/loki/api/v1/push";
    collectors.traces.enable = true;
    collectors.traces.exportURL = "https://homeserver.filip-nowakowicz.ts.net/obs/otlp";
    ingestAuth.username = "telemetry";
    ingestAuth.passwordFile = config.sops.secrets.observability_ingest_password.path;
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
