{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.observability;
  mkFileDirective = path: "$__file{${toString path}}";
in
{
  imports = [
    ./backends.nix
    ./collectors.nix
    ./dashboards.nix
  ];

  options.profiles.observability = {
    enable = lib.mkEnableOption "LGTM observability profile";

    grafana = {
      enable = lib.mkEnableOption "Grafana";
      adminUser = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Grafana admin username";
      };
      adminPasswordFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        description = "File containing the Grafana admin password";
      };
      secretKeyFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        description = "File containing the Grafana secret key for signing cookies/tokens";
      };
    };

    ingestAuth = {
      username = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Username for authenticated ingest";
      };
      passwordFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        description = "Password file for authenticated ingest";
      };
      serviceEnvironmentFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        description = "Path to an env file containing BASICAUTH_PASSWORD for the OTel collector.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = lib.mkIf cfg.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = "localhost";
        };
        security = {
          admin_user = cfg.grafana.adminUser;
        }
        // lib.optionalAttrs (cfg.grafana.secretKeyFile != null) {
          secret_key = mkFileDirective cfg.grafana.secretKeyFile;
        }
        // lib.optionalAttrs (cfg.grafana.adminPasswordFile != null) {
          admin_password = mkFileDirective cfg.grafana.adminPasswordFile;
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Mimir";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:9009/prometheus";
              uid = "mimir";
              isDefault = true;
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:3100";
              uid = "loki";
            }
            {
              name = "Tempo";
              type = "tempo";
              access = "proxy";
              url = "http://127.0.0.1:3200";
              uid = "tempo";
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "default";
              orgId = 1;
              folder = "Overview";
              type = "file";
              disableDeletion = false;
              editable = true;
              options.path = "/etc/grafana-dashboards";
            }
          ];
        };
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.grafana.enable [
      "d /var/lib/grafana 0750 grafana grafana -"
    ];
  };
}
