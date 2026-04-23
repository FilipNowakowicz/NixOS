# Tailscale ACLs as Nix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate `acl.hujson` from the host registry so Tailscale access control is declared once, version-controlled, and derived from the same source as every other host attribute.

**Architecture:** Extend `lib/hosts.nix` with explicit `tailscale` blocks per host, then implement `lib/acl.nix` — a pure function from `hostRegistry → { tagOwners, acls, hosts }`. Wire it as a `packages.${system}.tailscale-acl` derivation that writes the JSON file, following the exact same generator + test pattern already established by `lib/generators.nix`.

**Tech Stack:** Nix (pure functions, `lib.runTests`, `builtins.toJSON`), no new flake inputs required.

---

## File Map

| Action | Path                | Responsibility                                                            |
| ------ | ------------------- | ------------------------------------------------------------------------- |
| Modify | `lib/hosts.nix`     | Add `tailscale.tag` (and `tailscale.fqdn` where applicable) per host      |
| Create | `lib/acl.nix`       | Pure function: `mkAcl hostRegistry → attrset`                             |
| Create | `tests/lib/acl.nix` | `lib.runTests` unit tests for the generator                               |
| Modify | `flake.nix`         | Import acl.nix, expose `tailscale-acl` package, wire acl test into checks |

---

## Task 1: Extend host registry with Tailscale metadata

**Files:**

- Modify: `lib/hosts.nix`

The registry is the source of truth. Add an explicit `tailscale` block to every host that lives on the tailnet. Hosts without a `tailscale` attribute are ignored by the ACL generator. Use `tailscale.fqdn` only where the host has a known FQDN on the tailnet (currently just `homeserver`).

- [ ] **Step 1: Update `lib/hosts.nix`**

Replace the full file contents with:

```nix
# Host registry — single source of truth for all deployed hosts.
# To add a new host: add an entry here, create hosts/<name>/default.nix.
# Fields:
#   role        — human label; ready to drive modules later
#   deploy      — presence generates a deploy-rs node; absence = local-only (main)
#   sshPort     — VM-only; used to filter hosts for the VM script
#   diskSize    — VM-only; used by nixos-anywhere and qemu-img
#   tailnetFQDN — per-host Tailscale FQDN; unused metadata for now (host configs read lib/network.nix directly)
#   tailscale   — Tailscale metadata; presence means host is on the tailnet
#     .tag      — Tailscale tag assigned to this host (without "tag:" prefix)
#     .fqdn     — tailnet FQDN (only for hosts with a stable tailnet identity)
#   backup      — metadata; ready to drive a backup module later
{
  main = {
    role = "workstation";
    tailscale.tag = "workstation";
  };

  homeserver = {
    role = "homeserver";
    tailnetFQDN = "homeserver.filip-nowakowicz.ts.net";
    tailscale = {
      tag = "server";
      fqdn = "homeserver.filip-nowakowicz.ts.net";
    };
    deploy.sshUser = "user";
    backup.class = "critical";
  };

  vm = {
    role = "vm";
    sshPort = 2222;
    diskSize = "40G";
    deploy.sshUser = "user";
  };

  homeserver-vm = {
    role = "homeserver-vm";
    ip = "10.0.100.2";
  };
}
```

- [ ] **Step 2: Verify the flake still evaluates**

```bash
nix flake check --no-build 2>&1 | head -20
```

Expected: no errors (attribute access patterns in flake.nix don't touch `tailscale` yet).

- [ ] **Step 3: Commit**

```bash
git add lib/hosts.nix
git commit -m "feat(hosts): add tailscale metadata to host registry"
```

---

## Task 2: TDD — implement `lib/acl.nix`

**Files:**

- Create: `tests/lib/acl.nix`
- Create: `lib/acl.nix`

Follow the exact same pattern as `tests/lib/generators.nix` / `lib/generators.nix`. Write the test first, verify it fails (Nix eval error because the file doesn't exist), then implement.

- [ ] **Step 1: Write the failing test at `tests/lib/acl.nix`**

```nix
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
```

- [ ] **Step 2: Verify the test fails (file not found)**

```bash
nix eval --file tests/lib/acl.nix --arg nixpkgs 'builtins.getFlake "nixpkgs"' --arg system '"x86_64-linux"' 2>&1 | head -5
```

Expected: error containing `lib/acl.nix: No such file or directory` (Nix import error).

- [ ] **Step 3: Implement `lib/acl.nix`**

```nix
# Tailscale ACL generator — derives tag owners, host aliases, and base rules
# from the host registry. Feed the output to builtins.toJSON for acl.hujson.
{ lib }:
let
  tailscaleHosts = hosts: lib.filterAttrs (_: cfg: cfg ? tailscale) hosts;

  collectTagNames = hosts:
    lib.unique (map (cfg: cfg.tailscale.tag) (lib.attrValues (tailscaleHosts hosts)));

  mkTagOwners = tags:
    lib.listToAttrs (
      map (tag: { name = "tag:${tag}"; value = [ "autogroup:admin" ]; }) tags
    );

  mkHostAliases = hosts:
    lib.mapAttrs' (name: cfg: lib.nameValuePair name cfg.tailscale.fqdn)
      (lib.filterAttrs (_: cfg: cfg ? tailscale && cfg.tailscale ? fqdn) hosts);

in
{
  # Generate a Tailscale ACL attrset from the host registry.
  # Hosts without a `tailscale` attribute are ignored.
  # Serialize with builtins.toJSON to get acl.hujson content.
  mkAcl = hostRegistry: {
    tagOwners = mkTagOwners (collectTagNames hostRegistry);
    acls = [
      {
        action = "accept";
        src = [ "tag:workstation" ];
        dst = [ "tag:server:*" ];
      }
      {
        action = "accept";
        src = [ "autogroup:admin" ];
        dst = [ "*:*" ];
      }
    ];
    hosts = mkHostAliases hostRegistry;
  };
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
nix build '.#checks.x86_64-linux.lib-acl' 2>&1
```

Expected: you'll get an error about `lib-acl` not being in checks yet — that's fine, use the direct eval form instead:

```bash
nix eval --file tests/lib/acl.nix \
  --arg nixpkgs 'import <nixpkgs> {}' \
  --arg system '"x86_64-linux"' 2>&1
```

Alternatively, temporarily wire the test inline to evaluate it:

```bash
nix-instantiate --eval --strict - <<'EOF'
let
  nixpkgs = import <nixpkgs> {};
  lib = nixpkgs.lib;
  pkgs = nixpkgs;
  acl = import ./lib/acl.nix { inherit lib; };
  testRegistry = {
    main = { role = "workstation"; tailscale.tag = "workstation"; };
    homeserver = { role = "homeserver"; tailscale = { tag = "server"; fqdn = "homeserver.example.ts.net"; }; };
    homeserver-vm = { role = "homeserver-vm"; ip = "10.0.100.2"; };
  };
  result = acl.mkAcl testRegistry;
in lib.runTests {
  testTagOwnersWorkstation = { expr = result.tagOwners."tag:workstation"; expected = [ "autogroup:admin" ]; };
  testTagOwnerCount = { expr = lib.length (lib.attrNames result.tagOwners); expected = 2; };
  testHostAliasPresent = { expr = result.hosts.homeserver; expected = "homeserver.example.ts.net"; };
  testNonTailscaleHostExcluded = { expr = result.hosts ? homeserver-vm; expected = false; };
}
EOF
```

Expected: `[ ]` (empty list = all tests passed).

- [ ] **Step 5: Commit**

```bash
git add lib/acl.nix tests/lib/acl.nix
git commit -m "feat(lib): add Tailscale ACL generator with unit tests"
```

---

## Task 3: Expose `tailscale-acl` package and wire test into checks

**Files:**

- Modify: `flake.nix`

Two changes in one pass: import `lib/acl.nix` at the top of the `let` block, add the package, and add the check.

- [ ] **Step 1: Add acl generator import to the `let` block in `flake.nix`**

Find the line `invariants = import ./lib/invariants.nix { inherit lib pkgs; };` and add directly below it:

```nix
      aclGen = import ./lib/acl.nix { inherit lib; };
```

- [ ] **Step 2: Add `tailscale-acl` to `packages.${system}` in `flake.nix`**

Find the `packages.${system} = {` block (currently only has `installer-iso`) and add:

```nix
        tailscale-acl = pkgs.runCommand "tailscale-acl" {
          aclJson = builtins.toJSON (aclGen.mkAcl hostRegistry);
          passAsFile = [ "aclJson" ];
        } ''
          cp "$aclJsonPath" "$out"
        '';
```

- [ ] **Step 3: Add `lib-acl` to `checks.${system}` in `flake.nix`**

Find the `checks.${system} =` block. Inside the final `// { ... }` attrset (where `lib-generators` and `lib-generators-golden` live), add:

```nix
          lib-acl = import ./tests/lib/acl.nix {
            inherit nixpkgs system;
          };
```

- [ ] **Step 4: Build the package to verify JSON output**

```bash
nix build '.#tailscale-acl' && cat result
```

Expected output (pretty-printed by you mentally — actual output is compact JSON):

```json
{
  "acls": [
    { "action": "accept", "dst": ["tag:server:*"], "src": ["tag:workstation"] },
    { "action": "accept", "dst": ["*:*"], "src": ["autogroup:admin"] }
  ],
  "hosts": { "homeserver": "homeserver.filip-nowakowicz.ts.net" },
  "tagOwners": {
    "tag:server": ["autogroup:admin"],
    "tag:workstation": ["autogroup:admin"]
  }
}
```

Key things to confirm: `tagOwners` has both `tag:workstation` and `tag:server`, `hosts` has `homeserver` with the correct FQDN, `main` and `homeserver-vm` do NOT appear in `hosts`.

- [ ] **Step 5: Run the check**

```bash
nix build '.#checks.x86_64-linux.lib-acl'
```

Expected: build succeeds, `result` is a zero-byte file (the runCommand touch).

- [ ] **Step 6: Validate the full flake still checks clean**

```bash
nix flake check --no-build
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add flake.nix
git commit -m "feat(flake): expose tailscale-acl package and lib-acl check"
```

---

## Using the output

To apply the generated ACL to your tailnet:

```bash
# Build and inspect
nix build '.#tailscale-acl' && cat result | python3 -m json.tool

# Apply via Tailscale CLI (requires admin credentials)
tailscale acl set < result
```

The file is valid JSON (a subset of HuJSON), so Tailscale's API and CLI accept it directly.

---

## Self-Review

**Spec coverage:**

- ✅ Generate `acl.hujson` from registry — Task 3 produces the file via `nix build .#tailscale-acl`
- ✅ Single source of truth — tag assignments in `lib/hosts.nix`, rules derived by `lib/acl.nix`
- ✅ Depends on host registry — `mkAcl hostRegistry` is the primary input
- ✅ Who-can-reach-what — workstation→server and admin→all rules in `lib/acl.nix`

**Placeholder scan:** No TBDs, all code blocks are complete and self-contained.

**Type consistency:** `mkAcl` is defined in Task 2 as `acl.mkAcl`, referenced as `aclGen.mkAcl` in Task 3 (where `aclGen = import ./lib/acl.nix { inherit lib; }`). Consistent.
