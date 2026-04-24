{ lib, pkgs }:
let
  staticAddressesFor =
    cfg:
    lib.concatMap (
      network:
      let
        address = network.networkConfig.Address or null;
      in
      if address == null then
        [ ]
      else if builtins.isList address then
        address
      else
        [ address ]
    ) (lib.attrValues (cfg.systemd.network.networks or { }));

  stripPrefixLength = address: builtins.head (lib.splitString "/" address);

  hasLocalResticBackup =
    cfg:
    cfg.services.restic.backups ? local
    && (cfg.services.restic.backups.local ? repository)
    && cfg.services.restic.backups.local.repository != null;
in
{
  # Create a check derivation that validates config against assertions
  # hostName: string - host identifier for error messages
  # assertions: list of { name: string; check: config → bool }
  # config: the evaluated NixOS config to test
  mkInvariantCheck =
    hostName: assertions: config:
    let
      # Run each assertion and collect failures
      results = map (a: {
        inherit (a) name;
        passed = a.check config;
      }) assertions;

      failures = lib.filter (r: !r.passed) results;

      errorMsg = lib.concatMapStringsSep "\n" (f: "  ✗ ${f.name}") failures;
    in

    if failures == [ ] then
      pkgs.runCommand "invariant-check-${hostName}-pass" { } "touch $out"
    else
      pkgs.runCommand "invariant-check-${hostName}-fail" { } ''
        echo "Invariant check failed for '${hostName}':"
        echo "${errorMsg}"
        exit 1
      '';

  mkRegistryAssertions =
    hostName: hostMeta:
    [
      {
        name = "networking.hostName matches registry key";
        check = cfg: cfg.networking.hostName == hostName;
      }
    ]
    ++ lib.optionals (hostMeta ? deploy) [
      {
        name = "deployable hosts enable OpenSSH";
        check = cfg: cfg.services.openssh.enable;
      }
    ]
    ++ lib.optionals (hostMeta ? backup) [
      {
        name = "backup metadata configures local Restic backup";
        check = hasLocalResticBackup;
      }
    ]
    ++ lib.optionals ((hostMeta ? tailscale) || (hostMeta ? tailnetFQDN)) [
      {
        name = "tailnet metadata enables Tailscale";
        check = cfg: cfg.services.tailscale.enable;
      }
    ]
    ++ lib.optionals (hostMeta ? ip) [
      {
        name = "static IP metadata matches configured address";
        check =
          cfg:
          let
            expectedIp = hostMeta.ip;
          in
          lib.any (address: stripPrefixLength address == expectedIp) (staticAddressesFor cfg);
      }
    ];
}
