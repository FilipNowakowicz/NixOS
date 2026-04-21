# Host Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `lib/vm.nix` with a unified `lib/hosts.nix` covering all deployed hosts, and update `flake.nix` to derive nixosConfigurations and deploy-rs nodes from it.

**Architecture:** A single data file `lib/hosts.nix` replaces `lib/vm.nix`. Three filtered views are derived in `flake.nix`: all hosts → nixosConfigurations; hosts with a `deploy` attr → deploy-rs nodes; hosts with `sshPort`+`diskSize` → VM script env var. Host configs under `hosts/` are untouched.

**Tech Stack:** Nix, deploy-rs, flake.nix

---

## Files

- Create: `lib/hosts.nix`
- Modify: `flake.nix` (lines 61, 75-88, 192-209)
- Delete: `lib/vm.nix`

---

### Task 1: Create `lib/hosts.nix`

**Files:**
- Create: `lib/hosts.nix`

- [ ] **Step 1: Write `lib/hosts.nix`**

```nix
# Host registry — single source of truth for all deployed hosts.
# To add a new host: add an entry here, create hosts/<name>/default.nix.
# Fields:
#   role        — human label; ready to drive modules later
#   deploy      — presence generates a deploy-rs node; absence = local-only (main)
#   sshPort     — VM-only; used to filter hosts for the VM script
#   diskSize    — VM-only; used by nixos-anywhere and qemu-img
#   tailnetFQDN — per-host Tailscale FQDN
#   backup      — metadata; ready to drive a backup module later
{
  main = {
    role = "workstation";
  };

  homeserver = {
    role = "homeserver";
    tailnetFQDN = "homeserver.filip-nowakowicz.ts.net";
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
    sshPort = 2223;
    diskSize = "20G";
    deploy.sshUser = "user";
  };
}
```

- [ ] **Step 2: Verify it evaluates**

```bash
nix eval --file lib/hosts.nix
```

Expected: prints the attrset with all four hosts, no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/hosts.nix
git commit -m "feat: add unified host registry"
```

---

### Task 2: Update `flake.nix` to derive from `lib/hosts.nix`

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Replace `vmRegistry` import and derived infrastructure (lines 61, 75-88)**

Replace this block:
```nix
      vmRegistry = import ./lib/vm.nix;

      # ── VM-derived infrastructure ────────────────────────────────────────
      vmDeployNodes = lib.mapAttrs (name: _: {
        hostname = name;
        sshUser = "user";
        magicRollback = false;
        autoRollback = false;
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        };
      }) vmRegistry;

      vmNixosConfigs = lib.mapAttrs (name: _: mkNixos name) vmRegistry;
```

With:
```nix
      hostRegistry = import ./lib/hosts.nix;

      # VMs only — for the VM management script
      vmRegistry = lib.filterAttrs (_: cfg: cfg ? sshPort && cfg ? diskSize) hostRegistry;

      # ── Host-derived infrastructure ──────────────────────────────────────
      allNixosConfigs = lib.mapAttrs (name: _: mkNixos name) hostRegistry;

      deployableHosts = lib.filterAttrs (_: cfg: cfg ? deploy) hostRegistry;

      allDeployNodes = lib.mapAttrs (name: cfg: {
        hostname = name;
        sshUser = cfg.deploy.sshUser;
        magicRollback = false;
        autoRollback = false;
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        };
      }) deployableHosts;
```

- [ ] **Step 2: Replace `nixosConfigurations` (lines 192-195)**

Replace:
```nix
      # ── NixOS Configurations ────────────────────────────────────────────────
      nixosConfigurations = vmNixosConfigs // {
        main = mkNixos "main";
        homeserver = mkNixos "homeserver";
      };
```

With:
```nix
      # ── NixOS Configurations ────────────────────────────────────────────────
      nixosConfigurations = allNixosConfigs;
```

- [ ] **Step 3: Replace `deploy.nodes` (lines 198-209)**

Replace:
```nix
      # ── Deploy-RS ───────────────────────────────────────────────────────────
      deploy.nodes = vmDeployNodes // {
        homeserver = {
          hostname = "homeserver";
          sshUser = "user";
          magicRollback = false;
          autoRollback = false;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.homeserver;
          };
        };
      };
```

With:
```nix
      # ── Deploy-RS ───────────────────────────────────────────────────────────
      deploy.nodes = allDeployNodes;
```

- [ ] **Step 4: Verify the flake evaluates**

```bash
nix flake check --no-build
```

Expected: exits 0, no evaluation errors.

- [ ] **Step 5: Commit**

```bash
git add flake.nix
git commit -m "refactor: derive all hosts from lib/hosts.nix"
```

---

### Task 3: Delete `lib/vm.nix` and validate

**Files:**
- Delete: `lib/vm.nix`

- [ ] **Step 1: Delete `lib/vm.nix`**

```bash
git rm lib/vm.nix
```

- [ ] **Step 2: Verify flake still evaluates**

```bash
nix flake check --no-build
```

Expected: exits 0.

- [ ] **Step 3: Build all four nixosConfigurations**

```bash
nix build .#nixosConfigurations.main.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.homeserver.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.vm.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.homeserver-vm.config.system.build.toplevel --no-link
```

Expected: all four complete without errors.

- [ ] **Step 4: Verify deploy nodes are correct**

```bash
nix eval .#deploy.nodes --apply builtins.attrNames
```

Expected: `[ "homeserver" "homeserver-vm" "vm" ]` (main absent — it has no `deploy` attr).

- [ ] **Step 5: Verify VM registry shape is unchanged**

```bash
nix eval --expr '
  let hosts = import ./lib/hosts.nix;
      lib = (import <nixpkgs> {}).lib;
      vmRegistry = lib.filterAttrs (_: cfg: cfg ? sshPort && cfg ? diskSize) hosts;
  in builtins.toJSON vmRegistry
'
```

Expected: JSON with `vm` (sshPort 2222, diskSize 40G) and `homeserver-vm` (sshPort 2223, diskSize 20G) — same shape the VM script expects.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: remove lib/vm.nix, superseded by lib/hosts.nix"
```
