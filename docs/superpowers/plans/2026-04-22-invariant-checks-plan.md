# Configuration Invariant Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add extensible `nix flake check` tests that validate host configurations against security policies without requiring full VM boots.

**Architecture:** Create a simple Nix function (`mkInvariantCheck`) that evaluates a host's config and runs predicates against specific values. Integrate into `flake.nix` as a `checks` output with one check per host family. Assertions are pure predicates; errors are clear and actionable.

**Tech Stack:** Nix (stdlib), nixpkgs (pkgs.runCommand), existing nixosSystem configs

---

## File Structure

- **Create:** `lib/invariants.nix` — Core framework for invariant checks
- **Modify:** `flake.nix` — Add checks output (lines ~140, after mkNixos definition)

---

### Task 1: Create lib/invariants.nix framework

**Files:**

- Create: `lib/invariants.nix`

- [ ] **Step 1: Write the mkInvariantCheck function**

Create `/home/user/nix/lib/invariants.nix`:

```nix
{ lib, pkgs }:
{
  # Create a check derivation that validates config against assertions
  # hostName: string - host identifier for error messages
  # assertions: list of { name: string; check: config → bool }
  # config: the evaluated NixOS config to test
  mkInvariantCheck = hostName: assertions: config:
    let
      # Run each assertion and collect failures
      results = map (a: {
        name = a.name;
        passed = try (a.check config) false;
      }) assertions;

      failures = lib.filter (r: !r.passed) results;

      errorMsg = lib.concatMapStringsSep "\n"
        (f: "  ✗ ${f.name}")
        failures;
    in

    if failures == [] then
      pkgs.runCommand "invariant-check-${hostName}-pass" {} "touch $out"
    else
      pkgs.runCommand "invariant-check-${hostName}-fail" {}
        ''
          echo "Invariant check failed for '${hostName}':"
          echo "${errorMsg}"
          exit 1
        '';
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/invariants.nix
git commit -m "feat: add invariant check framework"
```

---

### Task 2: Add checks output to flake.nix (stateVersion baseline)

**Files:**

- Modify: `flake.nix` (after mkNixos definition, before outputs declaration)

- [ ] **Step 1: Import invariants.nix at the top of let block**

In `/home/user/nix/flake.nix`, find the `let` block that starts around line 65 and add after the existing imports (after `hostRegistry = import ./lib/hosts.nix;`):

```nix
      invariants = import ./lib/invariants.nix { inherit lib pkgs; };
```

- [ ] **Step 2: Add checks output (basic stateVersion for all hosts)**

In the `outputs` section (after allNixosConfigs is defined), add before `deployableHosts`:

```nix
      # ── Configuration Invariant Checks ──────────────────────────────────
      checks.x86_64-linux = {
        invariants-main = invariants.mkInvariantCheck "main" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
        ] allNixosConfigs.main.config;

        invariants-vm = invariants.mkInvariantCheck "vm" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
        ] allNixosConfigs.vm.config;

        invariants-homeserver-vm = invariants.mkInvariantCheck "homeserver-vm" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
        ] allNixosConfigs.homeserver-vm.config;

        invariants-homeserver = invariants.mkInvariantCheck "homeserver" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
        ] allNixosConfigs.homeserver.config;

        invariants-installer = invariants.mkInvariantCheck "installer" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
        ] allNixosConfigs.installer.config;
      };
```

- [ ] **Step 3: Run nix flake check to verify**

```bash
nix flake check
```

Expected: All 5 checks pass (should show no errors, exit 0).

- [ ] **Step 4: Commit**

```bash
git add flake.nix
git commit -m "feat: add baseline invariant checks (stateVersion)"
```

---

### Task 3: Add passwordless sudo invariants

**Files:**

- Modify: `flake.nix` (invariants-main, invariants-vm, invariants-homeserver-vm)

- [ ] **Step 1: Update invariants-main to check no passwordless sudo**

Replace the `invariants-main` check in flake.nix:

```nix
        invariants-main = invariants.mkInvariantCheck "main" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
          { name = "no passwordless sudo"; check = cfg: cfg.security.sudo.wheelNeedsPassword != false; }
        ] allNixosConfigs.main.config;
```

- [ ] **Step 2: Update invariants-vm to check passwordless sudo is enabled**

Replace the `invariants-vm` check:

```nix
        invariants-vm = invariants.mkInvariantCheck "vm" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
          { name = "passwordless sudo enabled"; check = cfg: cfg.security.sudo.wheelNeedsPassword == false; }
        ] allNixosConfigs.vm.config;
```

- [ ] **Step 3: Update invariants-homeserver-vm to check passwordless sudo is enabled**

Replace the `invariants-homeserver-vm` check:

```nix
        invariants-homeserver-vm = invariants.mkInvariantCheck "homeserver-vm" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
          { name = "passwordless sudo enabled"; check = cfg: cfg.security.sudo.wheelNeedsPassword == false; }
        ] allNixosConfigs.homeserver-vm.config;
```

- [ ] **Step 4: Run nix flake check to verify**

```bash
nix flake check
```

Expected: All 5 checks pass.

- [ ] **Step 5: Commit**

```bash
git add flake.nix
git commit -m "feat: add passwordless sudo invariants"
```

---

### Task 4: Add firewall invariants

**Files:**

- Modify: `flake.nix` (invariants-homeserver, invariants-homeserver-vm)

- [ ] **Step 1: Update invariants-homeserver to check firewall is enabled**

Replace the `invariants-homeserver` check:

```nix
        invariants-homeserver = invariants.mkInvariantCheck "homeserver" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
          { name = "firewall enabled"; check = cfg: cfg.networking.firewall.enable == true; }
        ] allNixosConfigs.homeserver.config;
```

- [ ] **Step 2: Update invariants-homeserver-vm to check firewall is enabled**

Replace the `invariants-homeserver-vm` check:

```nix
        invariants-homeserver-vm = invariants.mkInvariantCheck "homeserver-vm" [
          { name = "has stateVersion"; check = cfg: cfg.system.stateVersion != null; }
          { name = "passwordless sudo enabled"; check = cfg: cfg.security.sudo.wheelNeedsPassword == false; }
          { name = "firewall enabled"; check = cfg: cfg.networking.firewall.enable == true; }
        ] allNixosConfigs.homeserver-vm.config;
```

- [ ] **Step 3: Run nix flake check to verify**

```bash
nix flake check
```

Expected: All 5 checks pass.

- [ ] **Step 4: Commit**

```bash
git add flake.nix
git commit -m "feat: add firewall invariants"
```

---

### Task 5: Verify error messages are clear

**Files:** None (verification only)

- [ ] **Step 1: Intentionally break an invariant and observe the error**

Edit `modules/nixos/profiles/vm.nix` and change line 97 from:

```nix
  security.sudo.wheelNeedsPassword = false;
```

to:

```nix
  security.sudo.wheelNeedsPassword = true;
```

- [ ] **Step 2: Run nix flake check and observe failure**

```bash
nix flake check
```

Expected output should include:

```
Invariant check failed for 'vm':
  ✗ passwordless sudo enabled
```

- [ ] **Step 3: Revert the change**

Edit `modules/nixos/profiles/vm.nix` and restore line 97:

```nix
  security.sudo.wheelNeedsPassword = false;
```

- [ ] **Step 4: Run nix flake check to verify it passes again**

```bash
nix flake check
```

Expected: All checks pass.

---

## Self-Review Checklist

✓ **Spec coverage:** All requirements from design spec are addressed
✓ **No placeholders:** Every step contains actual code, exact paths, exact commands
✓ **Type consistency:** All assertions use consistent naming and logic
✓ **Commits:** One logical commit per feature area
