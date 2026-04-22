# E2E test for the systemd sandbox hardening score.
{ nixpkgs, system }:
let
  pkgs = import nixpkgs { inherit system; };
  sandbox = import ../../lib/sandbox.nix;
in
(import "${nixpkgs}/nixos/lib/testing-python.nix" {
  inherit system pkgs;
}).runTest
  {
    name = "profile-hardening-sandbox-score";

    nodes.machine = _: {
      systemd.services.test-sandboxed = {
        description = "Sandbox hardening score test service";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = sandbox // {
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          Type = "simple";
          DynamicUser = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          ReadWritePaths = [ ];
          UMask = "0077";
        };
      };

      environment.systemPackages = [
        pkgs.systemd
        pkgs.python3
      ];
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("test-sandboxed.service")

      # systemd-analyze security outputs a line like:
      #   → Overall exposure level for test-sandboxed.service: 1.9 OK ✓
      result = machine.succeed("systemd-analyze security test-sandboxed.service")
      print(result)

      # Extract numeric score and assert < 2.0
      machine.succeed(
          "systemd-analyze security test-sandboxed.service"
          " | grep -oP 'Overall exposure level.*: \\K[0-9.]+'"
          " | python3 -c 'import sys; score=float(sys.stdin.read().strip());"
          " assert score < 2.0, f\"score {score} >= 2.0 (target: <2.0)\"'"
      )
    '';
  }
