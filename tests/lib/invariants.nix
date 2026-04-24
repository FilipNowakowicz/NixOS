{
  nixpkgs,
  system,
  ...
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  invariants = import ../../lib/invariants.nix { inherit lib pkgs; };

  baseConfig = {
    networking.hostName = "homeserver";
    services = {
      openssh.enable = true;
      tailscale.enable = true;
      restic.backups.local.repository = "/persist/restic-repo";
    };
    systemd.network.networks."20-eth".networkConfig.Address = "10.0.100.2/24";
  };

  hostMeta = {
    deploy.sshUser = "user";
    backup.class = "critical";
    tailscale.tag = "server";
    ip = "10.0.100.2";
  };

  assertions = invariants.mkRegistryAssertions "homeserver" hostMeta;

  runAssertion =
    name: cfg:
    let
      assertion = lib.findFirst (candidate: candidate.name == name) null assertions;
    in
    if assertion == null then throw "missing assertion '${name}'" else assertion.check cfg;

  failures = lib.runTests {
    hostnameMatchesRegistryKey = {
      expr = runAssertion "networking.hostName matches registry key" baseConfig;
      expected = true;
    };

    deployableHostsRequireOpenSsh = {
      expr = runAssertion "deployable hosts enable OpenSSH" (
        baseConfig
        // {
          services = baseConfig.services // {
            openssh.enable = false;
          };
        }
      );
      expected = false;
    };

    backupMetadataRequiresRestic = {
      expr = runAssertion "backup metadata configures local Restic backup" (
        baseConfig
        // {
          services = baseConfig.services // {
            restic.backups = { };
          };
        }
      );
      expected = false;
    };

    tailnetMetadataRequiresTailscale = {
      expr = runAssertion "tailnet metadata enables Tailscale" (
        baseConfig
        // {
          services = baseConfig.services // {
            tailscale.enable = false;
          };
        }
      );
      expected = false;
    };

    staticIpMatchesConfiguredAddress = {
      expr = runAssertion "static IP metadata matches configured address" baseConfig;
      expected = true;
    };

    staticIpMismatchFails = {
      expr = runAssertion "static IP metadata matches configured address" (
        baseConfig
        // {
          systemd.network.networks."20-eth".networkConfig.Address = "10.0.100.3/24";
        }
      );
      expected = false;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "lib-invariants-tests" { } "touch $out"
else
  throw "lib/invariants.nix tests failed:\n${lib.generators.toPretty { } failures}"
