{
  nixpkgs,
  system,
  ...
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  invariants = import ../../lib/invariants.nix { inherit lib pkgs; };

  sampleResults = invariants.evaluateAssertions [
    {
      name = "bool checks remain supported";
      check = _: true;
    }
    {
      name = "rich message is preserved";
      check = _: {
        passed = false;
        message = "detailed failure";
      };
    }
    {
      name = "missing message falls back to name";
      check = _: { passed = false; };
    }
  ] { };

  failures = lib.runTests {
    testBoolCheckPasses = {
      expr = (lib.elemAt sampleResults 0).passed;
      expected = true;
    };

    testBoolCheckDefaultsMessageToName = {
      expr = (lib.elemAt sampleResults 0).message;
      expected = "bool checks remain supported";
    };

    testRichMessageIsPreserved = {
      expr = (lib.elemAt sampleResults 1).message;
      expected = "detailed failure";
    };

    testMissingMessageFallsBackToName = {
      expr = (lib.elemAt sampleResults 2).message;
      expected = "missing message falls back to name";
    };

    testInvalidResultIsRejected = {
      expr = (builtins.tryEval (invariants.normalizeCheckResult "broken" { nope = true; })).success;
      expected = false;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "lib-invariants-tests" { } "touch $out"
else
  throw "lib/invariants.nix tests failed:\n${lib.generators.toPretty { } failures}"
