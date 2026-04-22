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
    };
    homeserver = {
      role = "homeserver";
      tailscale = {
        tag = "server";
        fqdn = "homeserver.example.ts.net";
      };
    };
    homeserver-vm = {
      role = "homeserver-vm";
      ip = "10.0.100.2";
      # no tailscale — must be ignored by generator
    };
  };

  result = acl.mkAcl testRegistry;

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

    testHostAliasPresent = {
      expr = result.hosts.homeserver;
      expected = "homeserver.example.ts.net";
    };

    testHostNoFqdnExcluded = {
      expr = result.hosts ? main;
      expected = false;
    };

    testNonTailscaleHostExcluded = {
      expr = result.hosts ? homeserver-vm;
      expected = false;
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
      expected = [ "tag:server:*" ];
    };

    testSecondAclSrc = {
      expr = (lib.elemAt result.acls 1).src;
      expected = [ "autogroup:admin" ];
    };

    testAllAclsAccept = {
      expr = lib.all (rule: rule.action == "accept") result.acls;
      expected = true;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "lib-acl-tests" { } "touch $out"
else
  throw "lib/acl.nix tests failed:\n${lib.generators.toPretty { } failures}"
