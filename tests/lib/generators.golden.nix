{
  nixpkgs,
  system,
  ...
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  gen = import ../../lib/generators.nix { inherit lib; };
  dash = import ../../lib/dashboards.nix;

  # Example Alloy config (simple version without auth)
  alloyConfigBasic = gen.toAlloyHCL [
    {
      type = "loki.write";
      label = "target";
      body = {
        endpoint = gen.nestedBlock {
          url = "http://loki:3100";
        };
      };
    }
    {
      type = "loki.source.journal";
      label = "systemd";
      body = {
        forward_to = [ (gen.ref "loki.write.target.receiver") ];
        labels = {
          host = "test-host";
          job = "systemd-journal";
        };
        max_age = "12h";
      };
    }
  ];

  # Example dashboard with multiple panels (similar to observability.nix)
  exampleDashboard = dash.mkDashboard {
    uid = "example-dashboard";
    title = "Example Dashboard";
    panels = [
      (dash.timeseriesPanel {
        id = 1;
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
            expr = "(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100";
            legendFormat = "{{device}}";
          })
        ];
      })
      (dash.timeseriesPanel {
        id = 2;
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
            expr = "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "CPU";
          })
        ];
      })
      (dash.logsPanel {
        id = 3;
        title = "System Logs";
        ds = dash.lokiDS;
        gridPos = dash.gridPos {
          x = 0;
          y = 8;
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

  # Read golden files from repo
  goldenDir = ../../tests/lib/generators.golden.d;
  goldenAlloyBasic = builtins.readFile "${goldenDir}/alloy-basic.txt";
  goldenDashboard = builtins.readFile "${goldenDir}/dashboard-example.json";

  # Test: compare generated alloy config against golden
  testAlloyBasicSnapshot = {
    expr = alloyConfigBasic;
    expected = goldenAlloyBasic;
  };

  # Test: compare generated dashboard against golden
  # Dashboard golden file is already JSON, so we compare the generated JSON to it
  testDashboardSnapshot = {
    expr = builtins.toJSON exampleDashboard;
    expected = goldenDashboard;
  };

  failures = lib.runTests {
    inherit testAlloyBasicSnapshot testDashboardSnapshot;
  };

in
if failures == [ ] then
  pkgs.runCommand "lib-generators-golden-tests" { } "touch $out"
else
  throw "lib/generators.nix golden tests failed:\n${lib.generators.toPretty { } failures}"
