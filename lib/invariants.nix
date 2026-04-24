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
rec {
  normalizeCheckResult =
    assertionName: result:
    if builtins.isBool result then
      {
        passed = result;
        message = assertionName;
      }
    else if builtins.isAttrs result && result ? passed then
      {
        inherit (result) passed;
        message = result.message or assertionName;
      }
    else
      throw "Invariant '${assertionName}' must return a bool or { passed; message; }";

  evaluateAssertions =
    assertions: config:
    map (
      a:
      let
        normalized = normalizeCheckResult a.name (a.check config);
      in
      {
        inherit (a) name;
        inherit (normalized) passed message;
      }
    ) assertions;

  # Create a check derivation that validates config against assertions
  # hostName: string - host identifier for error messages
  # assertions: list of { name: string; check: config -> bool | { passed; message; } }
  # config: the evaluated NixOS config to test
  mkInvariantCheck =
    hostName: assertions: config:
    let
      results = evaluateAssertions assertions config;
      failures = lib.filter (r: !r.passed) results;
      errorMsg = lib.concatMapStringsSep "\n" (
        f: if f.message == "" || f.message == f.name then "  ✗ ${f.name}" else "  ✗ ${f.name}: ${f.message}"
      ) failures;
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
