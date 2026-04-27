# Unit tests for Tailscale ACL generator.
{
  nixpkgs,
  system,
  ...
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  acl = import ../../lib/acl.nix { inherit lib; };

  testRegistry = {
    main = {
      role = "workstation";
      tailscale.tag = "workstation";
      backup.class = "standard";
    };
    homeserver = {
      role = "homeserver";
      tailnetFQDN = "homeserver.example.ts.net";
      tailscale = {
        tag = "server";
        acceptFrom.workstation = [
          443
          22
          443
        ];
      };
      backup.class = "critical";
    };
    homeserver-vm = {
      role = "homeserver-vm";
      ip = "10.0.100.2";
      # no tailscale — must be ignored by generator
    };
  };

  result = acl.mkAcl testRegistry;
  rendered = builtins.toJSON result;

  failures = lib.runTests {
    testTagOwnersWorkstation = {
      expr = result.tagOwners."tag:workstation";
      expected = [ "autogroup:admin" ];
    };

    testTagOwnersServer = {
      expr = result.tagOwners."tag:server";
      expected = [ "autogroup:admin" ];
    };

    testTagOwnerCount = {
      expr = lib.length (lib.attrNames result.tagOwners);
      expected = 2;
    };

    testNoHostsKey = {
      expr = result ? hosts;
      expected = false;
    };

    testAclOutputShapeRemainsMinimal = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames result);
      expected = [
        "acls"
        "tagOwners"
      ];
    };

    testAclCount = {
      expr = lib.length result.acls;
      expected = 2;
    };

    testFirstAclSrc = {
      expr = (lib.elemAt result.acls 0).src;
      expected = [ "tag:workstation" ];
    };

    testFirstAclDst = {
      expr = (lib.elemAt result.acls 0).dst;
      expected = [
        "homeserver.example.ts.net:22"
        "homeserver.example.ts.net:443"
      ];
    };

    testSecondAclSrc = {
      expr = (lib.elemAt result.acls 1).src;
      expected = [ "autogroup:admin" ];
    };

    testAllAclsAccept = {
      expr = lib.all (rule: rule.action == "accept") result.acls;
      expected = true;
    };

    testSecondAclDst = {
      expr = (lib.elemAt result.acls 1).dst;
      expected = [ "*:*" ];
    };

    testNoWildcardServerDestination = {
      expr = lib.any (rule: lib.any (dst: dst == "tag:server:*") rule.dst) result.acls;
      expected = false;
    };

    testRenderedAclContainsExplicitPort22 = {
      expr = lib.hasInfix "\"homeserver.example.ts.net:22\"" rendered;
      expected = true;
    };

    testRenderedAclContainsExplicitPort443 = {
      expr = lib.hasInfix "\"homeserver.example.ts.net:443\"" rendered;
      expected = true;
    };

    testRenderedAclOmitsWildcardServerExposure = {
      expr = lib.hasInfix "\"tag:server:*\"" rendered;
      expected = false;
    };

    testNonTailscaleHostExcludedFromTagOwners = {
      expr = result.tagOwners ? "tag:homeserver-vm";
      expected = false;
    };

    testBackupMetadataDoesNotChangeAclCount = {
      expr = lib.length result.acls;
      expected = 2;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "lib-acl-tests" { } "touch $out"
else
  throw "lib/acl.nix tests failed:\n${lib.generators.toPretty { } failures}"
