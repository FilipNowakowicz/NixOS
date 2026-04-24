# E2E tests for the observability profile.
# Test 1: Alloy -> Loki pipeline (unauthenticated local stack).
# Test 2: Prometheus remoteWrite with basic auth (verifies auth header is sent).
{ nixpkgs, system }:
let
  pkgs = import nixpkgs { inherit system; };
in
(import "${nixpkgs}/nixos/lib/testing-python.nix" {
  inherit system pkgs;
}).runTest
  {
    name = "profile-observability";

    nodes = {
      # Local LGTM stack — Alloy ships journal logs to Loki.
      obs =
        { ... }:
        {
          imports = [ ../../modules/nixos/profiles/observability.nix ];

          profiles.observability = {
            enable = true;
            loki.enable = true;
            collectors.logs.enable = true;
          };

          environment.systemPackages = [ pkgs.curl ];
        };

      # Client-side auth path — Prometheus remoteWrite with basic_auth.
      # Uses a stub HTTPS echo server; verifies the Authorization header is present.
      obs_auth =
        { pkgs, ... }:
        {
          imports = [ ../../modules/nixos/profiles/observability.nix ];

          profiles.observability = {
            enable = true;
            collectors.metrics = {
              enable = true;
              remoteWriteURL = "http://127.0.0.1:19090/api/v1/push";
            };
            ingestAuth = {
              username = "telemetry";
              # Use a plain file — no sops needed in a test node.
              passwordFile = pkgs.writeText "obs-test-password" "test-secret";
            };
          };

          # Minimal stub: netcat loops accepting connections and captures headers.
          systemd.services.stub-ingest = {
            description = "Stub ingest endpoint that logs Authorization headers";
            wantedBy = [ "multi-user.target" ];
            script = ''
              mkdir -p /tmp/stub
              while true; do
                ${pkgs.netcat}/bin/nc -l -p 19090 > /tmp/stub/last-request 2>&1 || true
              done
            '';
            serviceConfig.Restart = "always";
          };

          environment.systemPackages = [
            pkgs.curl
            pkgs.netcat
          ];
        };
    };

    testScript = ''
      # ── Test 1: Alloy -> Loki ──────────────────────────────────────────────
      obs.start()
      obs.wait_for_unit("loki.service")
      obs.wait_for_unit("alloy.service")

      obs.wait_until_succeeds("curl -fsS http://127.0.0.1:3100/ready", timeout=30)

      obs.succeed("logger -t nixos-profile-test 'alloy-loki-e2e-marker'")

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

      # ── Test 2: Prometheus remoteWrite sends Authorization header ──────────
      obs_auth.start()
      obs_auth.wait_for_unit("stub-ingest.service")
      obs_auth.wait_for_unit("prometheus.service")

      # Give Prometheus time to attempt a remoteWrite scrape cycle
      obs_auth.sleep(20)

      # Verify the Authorization: Basic header appeared in the captured request
      obs_auth.succeed("grep -q 'Authorization: Basic' /tmp/stub/last-request")
    '';
  }
