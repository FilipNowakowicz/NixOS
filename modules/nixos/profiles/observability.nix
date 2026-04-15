{ config, lib, pkgs, ... }:
let
  cfg = config.profiles.observability;
  shouldUseIngestAuth = cfg.ingestAuth.username != null && cfg.ingestAuth.passwordFile != null;
  metricsRemoteWriteAuth = lib.optionalAttrs shouldUseIngestAuth {
    basic_auth = {
      username = cfg.ingestAuth.username;
      password_file = toString cfg.ingestAuth.passwordFile;
    };
  };
  alloyBasicAuth =
    if shouldUseIngestAuth then
      ''
                basic_auth {
                  username = "${cfg.ingestAuth.username}"
                  password_file = "${toString cfg.ingestAuth.passwordFile}"
                }
      ''
    else
      "";
  alloyConfig = ''
    loki.write "target" {
      endpoint {
        url = "${cfg.collectors.logs.pushURL}"
${alloyBasicAuth}
      }
    }

    loki.source.journal "systemd" {
      max_age       = "12h"
      labels = {
        job  = "systemd-journal",
        host = "${config.networking.hostName}",
      }
      forward_to = [loki.write.target.receiver]
    }
  '';
  dashboardJson = builtins.toJSON {
    id = null;
    uid = "homeserver-fleet-overview";
    title = "Homeserver Fleet Overview";
    timezone = "browser";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    panels = [
      {
        id = 1;
        title = "CPU Usage %";
        type = "timeseries";
        datasource = {
          type = "prometheus";
          uid = "mimir";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 0;
        };
        targets = [
          {
            expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
      {
        id = 2;
        title = "Systemd Journal Logs";
        type = "logs";
        datasource = {
          type = "loki";
          uid = "loki";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 8;
        };
        targets = [
          {
            expr = "{job=\"systemd-journal\"}";
            refId = "A";
          }
        ];
      }
      {
        id = 3;
        title = "Memory Usage %";
        type = "timeseries";
        datasource = {
          type = "prometheus";
          uid = "mimir";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 0;
        };
        targets = [
          {
            expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            legendFormat = "{{instance}}";
            refId = "A";
          }
        ];
      }
    ];
    time = {
      from = "now-1h";
      to = "now";
    };
  };

in
{
  options.profiles.observability = {
    enable = lib.mkEnableOption "LGTM observability profile";

    grafana.enable = lib.mkEnableOption "Grafana";
    grafana.adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Grafana admin username";
    };
    grafana.adminPasswordFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      description = "File containing the Grafana admin password";
    };
    loki.enable = lib.mkEnableOption "Loki";
    tempo.enable = lib.mkEnableOption "Tempo";
    mimir.enable = lib.mkEnableOption "Mimir";

    collectors.metrics = {
      enable = lib.mkEnableOption "Prometheus metrics collection";
      remoteWriteURL = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Remote write URL for Prometheus metrics";
      };
    };

    collectors.logs = {
      enable = lib.mkEnableOption "Loki log shipping";
      pushURL = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:3100/loki/api/v1/push";
        description = "Loki push URL used by Alloy";
      };
    };

    collectors.traces = {
      enable = lib.mkEnableOption "OpenTelemetry trace pipeline";
      receiverGRPCEndpoint = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:14317";
        description = "OpenTelemetry Collector OTLP gRPC receiver endpoint";
      };
      receiverHTTPEndpoint = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:14318";
        description = "OpenTelemetry Collector OTLP HTTP receiver endpoint";
      };
      exportURL = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Remote OTLP HTTP endpoint for trace export";
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
    };
  };

  config = lib.mkIf cfg.enable {
    services.loki = lib.mkIf cfg.loki.enable {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 3100;
          grpc_listen_port = 9096;
        };
        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
        };
        schema_config.configs = [
          {
            from = "2024-01-01";
            index = {
              prefix = "index_";
              period = "24h";
            };
            object_store = "filesystem";
            schema = "v13";
            store = "tsdb";
          }
        ];
        storage_config.filesystem.directory = "/var/lib/loki/chunks";
      };
    };

    services.tempo = lib.mkIf cfg.tempo.enable {
      enable = true;
      settings = {
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 3200;
          grpc_listen_port = 3201;
        };
        distributor.receivers.otlp.protocols = {
          grpc.endpoint = "127.0.0.1:4317";
          http.endpoint = "127.0.0.1:4318";
        };
        storage = {
          trace = {
            backend = "local";
            local.path = "/var/lib/tempo/blocks";
            wal.path = "/var/lib/tempo/wal";
          };
        };
      };
    };

    services.mimir = lib.mkIf cfg.mimir.enable {
      enable = true;
      configuration = {
        multitenancy_enabled = false;
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 9009;
        };
        blocks_storage = {
          backend = "filesystem";
          filesystem.dir = "/var/lib/mimir/blocks";
        };
        compactor.data_dir = "/var/lib/mimir/compactor";
        distributor.ring = {
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
        };
        ingester.ring = {
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
          replication_factor = 1;
        };
        ruler_storage = {
          backend = "filesystem";
          filesystem.dir = "/var/lib/mimir/rules";
        };
        store_gateway.sharding_ring.replication_factor = 1;
        alertmanager_storage = {
          backend = "filesystem";
          filesystem.dir = "/var/lib/mimir/alertmanager";
        };
      };
    };

    services.prometheus = lib.mkIf cfg.collectors.metrics.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9090;
      retentionTime = "24h";
      globalConfig.scrape_interval = "15s";

      exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9100;
        enabledCollectors = [
          "cpu"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "systemd"
          "thermal_zone"
        ];
      };

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "127.0.0.1:9090" ]; } ];
        }
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
      ];

      remoteWrite =
        if cfg.collectors.metrics.remoteWriteURL != null then
          [
            (
              {
                url = cfg.collectors.metrics.remoteWriteURL;
              }
              // metricsRemoteWriteAuth
            )
          ]
        else
          lib.optionals cfg.mimir.enable [
            {
              url = "http://127.0.0.1:9009/api/v1/push";
            }
          ];
    };

    services.grafana = lib.mkIf cfg.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = "localhost";
        };
        security =
          {
            secret_key = "SW2YcwTIb9zpOOhoPsMm";
            admin_user = cfg.grafana.adminUser;
          }
          // lib.optionalAttrs (cfg.grafana.adminPasswordFile != null) {
            admin_password = "$__file{${toString cfg.grafana.adminPasswordFile}}";
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

    environment.etc = lib.mkMerge [
      (lib.mkIf cfg.grafana.enable {
        "grafana-dashboards/homeserver-fleet-overview.json".text = dashboardJson;
      })
      (lib.mkIf cfg.collectors.logs.enable {
        "alloy/config.alloy".text = alloyConfig;
      })
    ];

    systemd.tmpfiles.rules = lib.mkMerge [
      (lib.mkIf cfg.grafana.enable [
        "d /var/lib/grafana 0750 grafana grafana -"
      ])
      (lib.mkIf cfg.loki.enable [
        "d /var/lib/loki 0750 loki loki -"
        "d /var/lib/loki/chunks 0750 loki loki -"
      ])
      (lib.mkIf cfg.collectors.metrics.enable [
        "d /var/lib/prometheus2 0750 prometheus prometheus -"
      ])
    ];

    services.alloy = lib.mkIf cfg.collectors.logs.enable {
      enable = true;
      configPath = "/etc/alloy/config.alloy";
    };
    systemd.services.alloy = lib.mkIf cfg.collectors.logs.enable {
      after = lib.optionals cfg.loki.enable [ "loki.service" ];
      requires = lib.optionals cfg.loki.enable [ "loki.service" ];
      serviceConfig.SupplementaryGroups = [ "systemd-journal" ];
    };

    services."opentelemetry-collector" = lib.mkIf cfg.collectors.traces.enable {
      enable = true;
      # contrib distribution required for the basicauth extension used for authenticated remote export
      package = pkgs.opentelemetry-collector-contrib;
      settings = {
        receivers.otlp.protocols = {
          grpc.endpoint = cfg.collectors.traces.receiverGRPCEndpoint;
          http.endpoint = cfg.collectors.traces.receiverHTTPEndpoint;
        };
        processors.batch = { };
        extensions = lib.optionalAttrs shouldUseIngestAuth {
          "basicauth/client" = {
            client_auth = {
              username = cfg.ingestAuth.username;
              password_file = toString cfg.ingestAuth.passwordFile;
            };
          };
        };
        exporters =
          if cfg.collectors.traces.exportURL != null then
            {
              otlphttp =
                {
                  endpoint = cfg.collectors.traces.exportURL;
                }
                // lib.optionalAttrs shouldUseIngestAuth {
                  auth.authenticator = "basicauth/client";
                };
            }
          else
            {
              otlp = {
                endpoint = "127.0.0.1:4317";
                tls.insecure = true;
              };
            };
        service.pipelines.traces = {
          receivers = [ "otlp" ];
          processors = [ "batch" ];
          exporters = if cfg.collectors.traces.exportURL != null then [ "otlphttp" ] else [ "otlp" ];
        };
        service.extensions = lib.optionals shouldUseIngestAuth [ "basicauth/client" ];
      };
    };
  };
}
