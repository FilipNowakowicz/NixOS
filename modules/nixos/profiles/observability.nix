{ config, lib, ... }:
let
  cfg = config.profiles.observability;
  alloyConfig = ''
    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
      }
    }

    loki.relabel "journal" {
      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    loki.source.journal "systemd" {
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels = {
        job  = "systemd-journal"
        host = "${config.networking.hostName}"
      }
      forward_to = [loki.write.local.receiver]
    }
  '';
  dashboardJson = builtins.toJSON {
    id = null;
    uid = "homeserver-vm-overview";
    title = "Homeserver VM Overview";
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
    loki.enable = lib.mkEnableOption "Loki";
    tempo.enable = lib.mkEnableOption "Tempo";
    mimir.enable = lib.mkEnableOption "Mimir";

    collectors.metrics.enable = lib.mkEnableOption "Prometheus metrics collection";
    collectors.logs.enable = lib.mkEnableOption "Loki log shipping";
    collectors.traces.enable = lib.mkEnableOption "OpenTelemetry trace pipeline";
  };

  config = lib.mkIf cfg.enable {
    services.loki = lib.mkIf cfg.loki.enable {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 3100;
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
        };
        distributor.receivers.otlp.protocols = {
          grpc.endpoint = "127.0.0.1:4317";
          http.endpoint = "127.0.0.1:4318";
        };
        storage = {
          trace = {
            backend = "local";
            local.path = "/var/lib/tempo/traces";
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

      remoteWrite = lib.optionals cfg.mimir.enable [
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
        security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
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
        "grafana-dashboards/homeserver-vm-overview.json".text = dashboardJson;
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
      after = [ "loki.service" ];
      requires = [ "loki.service" ];
      serviceConfig.SupplementaryGroups = [ "systemd-journal" ];
    };

    services."opentelemetry-collector" = lib.mkIf cfg.collectors.traces.enable {
      enable = true;
      settings = {
        receivers.otlp.protocols = {
          grpc.endpoint = "127.0.0.1:14317";
          http.endpoint = "127.0.0.1:14318";
        };
        processors.batch = { };
        exporters.otlp = {
          endpoint = "127.0.0.1:4317";
          tls.insecure = true;
        };
        service.pipelines.traces = {
          receivers = [ "otlp" ];
          processors = [ "batch" ];
          exporters = [ "otlp" ];
        };
      };
    };
  };
}
