{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.observability;
  dash = import ../../../../lib/dashboards.nix;

  fleetDashboard = dash.mkDashboard {
    uid = "homeserver-fleet-overview";
    title = "Homeserver Fleet Overview";
    panels = [
      (dash.timeseriesPanel {
        id = 1;
        title = "CPU Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 0;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "100 - (avg by(host) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "{{host}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 3;
        title = "Memory Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 0;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            legendFormat = "{{host}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 4;
        title = "Disk Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 8;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = ''(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|efivarfs|squashfs|devtmpfs",mountpoint="/"} / node_filesystem_size_bytes) * 100'';
            legendFormat = "{{host}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 5;
        title = "Failed Systemd Units";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 8;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = ''sum by(host) (node_systemd_unit_state{state="failed"})'';
            legendFormat = "{{host}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 6;
        title = "Backup Age (hours)";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 16;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "(time() - restic_last_backup_timestamp_seconds) / 3600";
            legendFormat = "{{host}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 7;
        title = "Backup Check Age (hours)";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 16;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "(time() - restic_last_check_timestamp_seconds) / 3600";
            legendFormat = "{{host}}";
          })
        ];
      })
      (dash.logsPanel {
        id = 2;
        title = "Systemd Journal Logs";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 24;
          w = 24;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{job=\"systemd-journal\"}";
          })
        ];
      })
    ];
  };

  securityEventsDashboard = dash.mkDashboard {
    uid = "security-events";
    title = "Security Events";
    timeFrom = "now-24h";
    panels = [
      (dash.logsPanel {
        id = 20;
        title = "Recent Audit Events";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 0;
          w = 24;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{job=\"audit-journal\"}";
          })
        ];
      })
      (dash.logsPanel {
        id = 21;
        title = "Sudo Activity";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 8;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{job=\"audit-journal\",audit_event_type=\"sudo\"}";
          })
        ];
      })
      (dash.logsPanel {
        id = 22;
        title = "SSH Sessions";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 8;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{job=\"audit-journal\",audit_event_type=\"ssh\"}";
          })
        ];
      })
      (dash.logsPanel {
        id = 23;
        title = "Service Failures";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 16;
          w = 24;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{job=\"audit-journal\",audit_event_type=\"service_failure\"}";
          })
        ];
      })
    ];
  };

  dashboardSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to render this dashboard to /etc/grafana-dashboards.";
      };
      definition = lib.mkOption {
        type = lib.types.attrs;
        description = "Grafana dashboard attrset (typically built via lib/dashboards.nix).";
      };
    };
  };
in
{
  options.profiles.observability.dashboards = lib.mkOption {
    type = lib.types.attrsOf dashboardSubmodule;
    default = { };
    description = ''
      Grafana dashboards to render under /etc/grafana-dashboards/<name>.json.
      The built-in `fleet` dashboard is pre-registered; toggle it via
      `dashboards.fleet.enable`. Add new dashboards by setting
      `dashboards.<name>.definition`.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.grafana.enable) {
    profiles.observability.dashboards.fleet = {
      enable = lib.mkDefault false;
      definition = fleetDashboard;
    };

    profiles.observability.dashboards.security-events = {
      enable = lib.mkDefault false;
      definition = securityEventsDashboard;
    };

    environment.etc = lib.mapAttrs' (name: dashboard: {
      name = "grafana-dashboards/${dashboard.definition.uid or name}.json";
      value.text = builtins.toJSON dashboard.definition;
    }) (lib.filterAttrs (_: d: d.enable) cfg.dashboards);
  };
}
