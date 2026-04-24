# Client-side observability: ships metrics, logs, and traces to a remote ingest stack.
# Hosts import this module and set remoteEndpoint.host; the module wires all three
# collectors and creates the sops template expected by the OTel collector.
# The host must still declare sops.secrets.observability_ingest_password.
{ config, lib, ... }:
let
  cfg = config.profiles.observability-client;
in
{
  options.profiles.observability-client = {
    enable = lib.mkEnableOption "remote observability client (metrics, logs, traces)";

    remoteEndpoint.host = lib.mkOption {
      type = lib.types.str;
      description = "Base hostname for the observability ingest stack (Tailscale FQDN)";
    };

    ingestAuth.username = lib.mkOption {
      type = lib.types.str;
      default = "telemetry";
      description = "Username for authenticated push; must match the server htpasswd entry";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.templates."otel-env" = {
      content = "BASICAUTH_PASSWORD=${config.sops.placeholder.observability_ingest_password}";
      mode = "0400";
    };

    profiles.observability = {
      enable = true;
      collectors = {
        metrics = {
          enable = true;
          remoteWriteURL = "https://${cfg.remoteEndpoint.host}/obs/mimir/api/v1/push";
        };
        logs = {
          enable = true;
          pushURL = "https://${cfg.remoteEndpoint.host}/obs/loki/loki/api/v1/push";
        };
        traces = {
          enable = true;
          exportURL = "https://${cfg.remoteEndpoint.host}/obs/otlp/v1/traces";
        };
      };
      ingestAuth = {
        inherit (cfg.ingestAuth) username;
        passwordFile = config.sops.secrets.observability_ingest_password.path;
        serviceEnvironmentFile = config.sops.templates."otel-env".path;
      };
    };
  };
}
