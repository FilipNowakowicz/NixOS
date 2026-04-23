# Secret Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rotate the committed plaintext initrd SSH host key into sops, and replace the `/tmp` OTel env file with a `sops.templates`-rendered secret at a safe path.

**Architecture:** Two independent changes to `hosts/main/default.nix`. The OTel fix also extends the observability module with a `serviceEnvironmentFile` option so the safe pattern is reusable. The initrd key is stored in the existing sops secrets file and referenced via its decrypted runtime path.

**Tech Stack:** sops-nix (`sops.secrets`, `sops.templates`, `sops.placeholder`), NixOS `boot.initrd.secrets`, `nh os switch`

---

## File Map

| File                                       | Change                                                                                                                                                                                         |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `modules/nixos/profiles/observability.nix` | Add `ingestAuth.serviceEnvironmentFile` option; wire `EnvironmentFiles` on OTel service                                                                                                        |
| `hosts/main/default.nix`                   | Add `sops.templates."otel-env"`; add `ingestAuth.serviceEnvironmentFile`; remove `preStart`+`/tmp` override; add `sops.secrets.initrd_ssh_host_ed25519_key`; update `boot.initrd.secrets` path |
| `hosts/main/secrets/secrets.yaml`          | Add `initrd_ssh_host_ed25519_key` encrypted secret                                                                                                                                             |
| `hosts/main/initrd-ssh-host-key`           | Delete                                                                                                                                                                                         |
| `hosts/main/initrd-ssh-host-key.pub`       | Delete                                                                                                                                                                                         |

---

## Task 1: Add `serviceEnvironmentFile` option to observability module

**Files:**

- Modify: `modules/nixos/profiles/observability.nix:316-327` (options.profiles.observability.ingestAuth block)
- Modify: `modules/nixos/profiles/observability.nix:606-610` (config block, after alloy service)

- [ ] **Step 1: Add option to ingestAuth block**

In `modules/nixos/profiles/observability.nix`, find the `ingestAuth` options block (currently ends with `passwordFile`). Add `serviceEnvironmentFile` after `passwordFile`:

```nix
    ingestAuth = {
      username = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Username for authenticated ingest";
      };
      passwordFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        description = "Password file for authenticated ingest";
      };
      serviceEnvironmentFile = lib.mkOption {
        type = with lib.types; nullOr path;
        default = null;
        description = "Path to an env file containing BASICAUTH_PASSWORD for the OTel collector.";
      };
    };
```

- [ ] **Step 2: Wire EnvironmentFiles in the config section**

In `modules/nixos/profiles/observability.nix`, find the line:

```nix
    systemd.services.alloy = lib.mkIf cfg.collectors.logs.enable {
```

Add a new block **after** the closing `};` of the alloy service (before the closing `}` of `config = lib.mkIf cfg.enable {`):

```nix
    systemd.services."opentelemetry-collector" = lib.mkIf (cfg.collectors.traces.enable && cfg.ingestAuth.serviceEnvironmentFile != null) {
      serviceConfig.EnvironmentFiles = [ cfg.ingestAuth.serviceEnvironmentFile ];
    };
```

- [ ] **Step 3: Verify the file evaluates (syntax check)**

```bash
nix-instantiate --parse modules/nixos/profiles/observability.nix > /dev/null && echo OK
```

Expected: `OK`

---

## Task 2: Fix OTel secret leak in `hosts/main/default.nix`

**Files:**

- Modify: `hosts/main/default.nix:256-265` (systemd.services block)
- Modify: `hosts/main/default.nix:283-295` (sops block)
- Modify: `hosts/main/default.nix:99-102` (profiles.observability.ingestAuth block)

- [ ] **Step 1: Remove preStart and EnvironmentFiles override**

In `hosts/main/default.nix`, find and replace the systemd.services block:

Old:

```nix
  systemd.services = {
    prometheus.serviceConfig = {
      TimeoutStopSec = "20s";
      SupplementaryGroups = [ "telemetry-ingest" ];
    };
    "opentelemetry-collector".serviceConfig.SupplementaryGroups = lib.mkAfter [ "telemetry-ingest" ];
    "opentelemetry-collector".preStart =
      "${pkgs.bash}/bin/bash -c 'export BASICAUTH_PASSWORD=\"$(cat ${config.sops.secrets.observability_ingest_password.path})\" && echo BASICAUTH_PASSWORD=\"$BASICAUTH_PASSWORD\" > /tmp/otel-env'";
    "opentelemetry-collector".serviceConfig.EnvironmentFiles = [ "/tmp/otel-env" ];
  };
```

New:

```nix
  systemd.services = {
    prometheus.serviceConfig = {
      TimeoutStopSec = "20s";
      SupplementaryGroups = [ "telemetry-ingest" ];
    };
    "opentelemetry-collector".serviceConfig.SupplementaryGroups = lib.mkAfter [ "telemetry-ingest" ];
  };
```

- [ ] **Step 2: Add sops.templates entry for otel-env**

In `hosts/main/default.nix`, find the `sops = {` block. Add a `templates` attribute inside it:

Old:

```nix
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
```

New:

```nix
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    templates."otel-env" = {
      content = "BASICAUTH_PASSWORD=${config.sops.placeholder.observability_ingest_password}";
      owner = "opentelemetry-collector";
      mode = "0400";
    };
    secrets = {
```

- [ ] **Step 3: Wire serviceEnvironmentFile in profiles.observability**

In `hosts/main/default.nix`, find the `ingestAuth` block inside `profiles.observability`:

Old:

```nix
    ingestAuth = {
      username = "admin";
      passwordFile = config.sops.secrets.observability_ingest_password.path;
    };
```

New:

```nix
    ingestAuth = {
      username = "admin";
      passwordFile = config.sops.secrets.observability_ingest_password.path;
      serviceEnvironmentFile = config.sops.templates."otel-env".path;
    };
```

- [ ] **Step 4: Verify main config evaluates**

```bash
nix build '.#nixosConfigurations.main.config.system.build.toplevel' --no-link 2>&1 | tail -5
```

Expected: build succeeds (no errors)

- [ ] **Step 5: Commit OTel fix**

```bash
git add modules/nixos/profiles/observability.nix hosts/main/default.nix
git commit -m "fix(main): replace /tmp otel-env with sops.templates rendered secret"
```

---

## Task 3: Rotate initrd SSH key

**Files:**

- Modify: `hosts/main/secrets/secrets.yaml` (add encrypted key)
- Modify: `hosts/main/default.nix:66-68` (boot.initrd.secrets + sops.secrets)
- Delete: `hosts/main/initrd-ssh-host-key`
- Delete: `hosts/main/initrd-ssh-host-key.pub`

- [ ] **Step 1: Generate a new ed25519 key**

```bash
ssh-keygen -t ed25519 -f /tmp/new_initrd_key -N "" -C "initrd-ssh-host-key"
```

Expected: creates `/tmp/new_initrd_key` (private) and `/tmp/new_initrd_key.pub` (public)

- [ ] **Step 2: Add key to secrets.yaml**

```bash
sops set hosts/main/secrets/secrets.yaml '["initrd_ssh_host_ed25519_key"]' "$(cat /tmp/new_initrd_key)"
```

Expected: `hosts/main/secrets/secrets.yaml` is rewritten with the new encrypted entry. Verify with `sops --decrypt hosts/main/secrets/secrets.yaml | grep -A3 initrd_ssh_host_ed25519_key` — should show the key header.

- [ ] **Step 3: Add sops secret declaration in default.nix**

In `hosts/main/default.nix`, find the `secrets = {` block inside `sops`:

Old:

```nix
    secrets = {
      user_password.neededForUsers = true;
      observability_ingest_password = {
        group = "telemetry-ingest";
        mode = "0440";
      };
      restic_password = { };
    };
```

New:

```nix
    secrets = {
      user_password.neededForUsers = true;
      observability_ingest_password = {
        group = "telemetry-ingest";
        mode = "0440";
      };
      restic_password = { };
      initrd_ssh_host_ed25519_key = { };
    };
```

- [ ] **Step 4: Update boot.initrd.secrets to reference sops-decrypted path**

In `hosts/main/default.nix`, find:

Old:

```nix
      secrets = {
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce ./initrd-ssh-host-key;
      };
```

New:

```nix
      secrets = {
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce "/run/secrets/initrd_ssh_host_ed25519_key";
      };
```

- [ ] **Step 5: Verify main config evaluates**

```bash
nix build '.#nixosConfigurations.main.config.system.build.toplevel' --no-link 2>&1 | tail -5
```

Expected: build succeeds

- [ ] **Step 6: Delete plaintext key files**

```bash
git rm hosts/main/initrd-ssh-host-key hosts/main/initrd-ssh-host-key.pub
```

- [ ] **Step 7: Clean up temp key files**

```bash
rm -f /tmp/new_initrd_key /tmp/new_initrd_key.pub
```

- [ ] **Step 8: Commit initrd key rotation**

```bash
git add hosts/main/secrets/secrets.yaml hosts/main/default.nix
git commit -m "fix(main): rotate initrd SSH host key — store encrypted in sops"
```

---

## Task 4: Final validation

- [ ] **Step 1: Run invariants check for main**

```bash
nix build '.#checks.x86_64-linux.invariants-main' 2>&1 | tail -10
```

Expected: build succeeds

- [ ] **Step 2: Run flake check**

```bash
nix flake check 2>&1 | tail -10
```

Expected: no errors
