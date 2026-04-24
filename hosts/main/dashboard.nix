{ config, ... }:
let
  dash = import ../../lib/dashboards.nix;
  host = config.networking.hostName;
  hostSel = dash.hostSelector host;
in
{
  profiles.observability.dashboards.main-machine.definition = dash.mkDashboard {
    uid = "main-machine";
    title = "Main Machine";
    panels = [
      (dash.timeseriesPanel {
        id = 10;
        title = "Disk Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 0;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "(node_filesystem_size_bytes{${hostSel},fstype!~\"tmpfs|efivarfs|overlay\"} - node_filesystem_avail_bytes{${hostSel},fstype!~\"tmpfs|efivarfs|overlay\"}) / node_filesystem_size_bytes{${hostSel},fstype!~\"tmpfs|efivarfs|overlay\"} * 100";
            legendFormat = "{{device}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 11;
        title = "CPU Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 0;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "100 - (avg(rate(node_cpu_seconds_total{${hostSel},mode=\"idle\"}[5m])) * 100)";
            legendFormat = "CPU";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 12;
        title = "Memory Usage %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 8;
          w = 8;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "(1 - (node_memory_MemAvailable_bytes{${hostSel}} / node_memory_MemTotal_bytes{${hostSel}})) * 100";
            legendFormat = "Memory";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 13;
        title = "Thermal Zones";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 8;
          y = 8;
          w = 8;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "node_thermal_zone_temp{${hostSel}}";
            legendFormat = "{{zone}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 14;
        title = "Battery %";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 16;
          y = 8;
          w = 8;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "node_power_supply_capacity{${hostSel}}";
            legendFormat = "{{power_supply}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 15;
        title = "Failed Systemd Units";
        ds = dash.mimirDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 16;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "node_systemd_unit_state{${hostSel},state=\"failed\"} == 1";
            legendFormat = "{{unit}}";
          })
        ];
      })
      (dash.logsPanel {
        id = 16;
        title = "Kernel Errors";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 12;
          y = 16;
          w = 12;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{${hostSel},job=\"systemd-journal\"} |= \"kernel\" |~ \"(error|fail|oops|panic)\"";
          })
        ];
      })
      (dash.logsPanel {
        id = 17;
        title = "Systemd Journal Errors";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 24;
          w = 24;
          h = 8;
        };
        targets = [
          (dash.target {
            expr = "{${hostSel},job=\"systemd-journal\"} |= \"Failed\"";
          })
        ];
      })
    ];
  };
}
