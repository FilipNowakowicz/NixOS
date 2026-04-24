# E2E test for the observability profile (Alloy -> Loki pipeline).
{ nixpkgs, system }:
let
  pkgs = import nixpkgs { inherit system; };
in
(import "${nixpkgs}/nixos/lib/testing-python.nix" {
  inherit system pkgs;
}).runTest
  {
    name = "profile-observability-alloy-loki";

    nodes.obs =
      { ... }:
      {
        imports = [ ../../modules/nixos/profiles/observability ];

        profiles.observability = {
          enable = true;
          loki.enable = true;
          collectors.logs.enable = true;
        };

        environment.systemPackages = [ pkgs.curl ];
      };

    testScript = ''
      start_all()
      obs.wait_for_unit("loki.service")
      obs.wait_for_unit("alloy.service")

      # Wait for Loki's HTTP endpoint to be ready
      obs.wait_until_succeeds("curl -fsS http://127.0.0.1:3100/ready", timeout=30)

      # Write a uniquely-tagged log entry to the systemd journal
      obs.succeed("logger -t nixos-profile-test 'alloy-loki-e2e-marker'")

      # Query Loki until the log line appears (Alloy polls the journal every few seconds)
      obs.wait_until_succeeds(
          "NOW=$(date +%s);"
          " curl -fsS -G http://127.0.0.1:3100/loki/api/v1/query_range"
          " --data-urlencode 'query={job=\"systemd-journal\"}'"
          " --data-urlencode \"start=$((NOW - 300))000000000\""
          " --data-urlencode \"end=''${NOW}000000000\""
          " --data-urlencode 'limit=100'"
          " | grep -q 'alloy-loki-e2e-marker'",
          timeout=90,
      )
    '';
  }
