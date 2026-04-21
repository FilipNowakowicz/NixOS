{ lib, pkgs }:
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
}
