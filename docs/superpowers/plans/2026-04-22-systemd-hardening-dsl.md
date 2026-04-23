# Systemd Hardening DSL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `lib/sandbox.nix` into a proper `services.hardened.<name>` NixOS module and apply it to every service shipped across all hosts.

**Architecture:** A new NixOS module at `modules/nixos/services/hardened.nix` defines `services.hardened` as an `attrsOf submodule` option. Each entry applies a hardening baseline (`lib/sandbox.nix` options) to the named `systemd.services.<name>.serviceConfig`, with per-service `extraConfig` for additive overrides or `null` values to disable specific base options. The module is loaded for all hosts via the existing `{ imports = [ ./modules/nixos ]; }` in `flake.nix`.

**Tech Stack:** Nix module system (`lib.types`, `lib.mkMerge`, `lib.mapAttrsToList`, `lib.filterAttrs`, `lib.mkIf`), NixOS systemd service options.

---

## File Map

| Action | Path                                  | Responsibility                                                                           |
| ------ | ------------------------------------- | ---------------------------------------------------------------------------------------- |
| Create | `modules/nixos/services/hardened.nix` | New NixOS module — defines `services.hardened` option and wires into `systemd.services`  |
| Modify | `modules/nixos/default.nix`           | Add import for `hardened.nix`                                                            |
| Modify | `tests/nixos/profile-hardening.nix`   | Use `services.hardened` module instead of raw `lib/sandbox.nix` import                   |
| Modify | `hosts/homeserver-vm/default.nix`     | Replace `commonSandbox //` pattern with `services.hardened.<name>`                       |
| Modify | `hosts/homeserver/default.nix`        | Replace `commonSandbox //` pattern with `services.hardened.<name>`                       |
| Modify | `hosts/main/default.nix`              | Replace `hwDaemonSandbox` local + custom service configs with `services.hardened.<name>` |
| Delete | `lib/sandbox.nix`                     | Superseded by the module                                                                 |

---

## Base Hardening Options Reference

These are the options defined in `lib/sandbox.nix` that become the module's default baseline:

```nix
{
  NoNewPrivileges = true;
  PrivateTmp = true;
  PrivateDevices = true;
  ProtectSystem = "strict";
  ProtectHome = true;
  ProtectControlGroups = true;
  ProtectKernelTunables = true;
  ProtectKernelModules = true;
  ProtectKernelLogs = true;
  ProtectHostname = true;
  ProtectClock = true;
  LockPersonality = true;
  MemoryDenyWriteExecute = true;
  RestrictSUIDSGID = true;
  RestrictRealtime = true;
  RestrictNamespaces = true;
  SystemCallArchitectures = "native";
  SystemCallFilter = [ "@system-service" ];
  RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
}
```

**Null-means-disabled contract:** If a service sets an option to `null` in `extraConfig`, that option is removed from the final `serviceConfig` (filtered out before passing to systemd). This allows services to opt out of specific base options without losing the rest of the baseline.

---

## Task 1: Write Failing Test

Update the profile-hardening test to use `services.hardened` instead of raw `lib/sandbox.nix`.

**Files:**

- Modify: `tests/nixos/profile-hardening.nix`

- [ ] **Step 1: Update profile-hardening.nix**

Replace the file content entirely:

```nix
# E2E test for the systemd sandbox hardening score using the services.hardened module.
{ nixpkgs, system }:
let
  pkgs = import nixpkgs { inherit system; };
in
(import "${nixpkgs}/nixos/lib/testing-python.nix" {
  inherit system pkgs;
}).runTest
  {
    name = "profile-hardening-sandbox-score";

    nodes.machine =
      { ... }:
      {
        imports = [ ../../modules/nixos/services/hardened.nix ];

        services.hardened.test-sandboxed = {
          extraConfig = {
            ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
            Type = "simple";
            DynamicUser = true;
            CapabilityBoundingSet = "";
            AmbientCapabilities = "";
            ReadWritePaths = [ ];
            UMask = "0077";
          };
        };

        systemd.services.test-sandboxed = {
          description = "Sandbox hardening score test service";
          wantedBy = [ "multi-user.target" ];
        };

        environment.systemPackages = [
          pkgs.systemd
          pkgs.python3
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("test-sandboxed.service")

      # systemd-analyze security outputs a line like:
      #   → Overall exposure level for test-sandboxed.service: 1.9 OK ✓
      result = machine.succeed("systemd-analyze security test-sandboxed.service")
      print(result)

      # Extract numeric score and assert < 2.0
      machine.succeed(
          "systemd-analyze security test-sandboxed.service"
          " | grep -oP 'Overall exposure level.*: \\K[0-9.]+'"
          " | python3 -c 'import sys; score=float(sys.stdin.read().strip());"
          " assert score < 2.0, f\"score {score} >= 2.0 (target: <2.0)\"'"
      )
    '';
  }
```

- [ ] **Step 2: Verify the test fails (module doesn't exist yet)**

```bash
nix build '.#checks.x86_64-linux.profile-hardening' 2>&1 | head -30
```

Expected: error referencing `../../modules/nixos/services/hardened.nix` not found.

---

## Task 2: Create the Hardened Module

**Files:**

- Create: `modules/nixos/services/hardened.nix`

- [ ] **Step 1: Create modules/nixos/services/hardened.nix**

```nix
{
  config,
  lib,
  ...
}:
let
  baseHardening = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectControlGroups = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectHostname = true;
    ProtectClock = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" ];
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
  };

  hardenedServiceType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply the hardening baseline to this service.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = ''
          Additional serviceConfig options merged on top of the baseline.
          Set any base option to null to remove it from the final config
          (e.g. PrivateDevices = null for services that need /dev access).
        '';
      };
    };
  };

  cfg = config.services.hardened;
in
{
  options.services.hardened = lib.mkOption {
    type = lib.types.attrsOf hardenedServiceType;
    default = { };
    description = ''
      Apply a security hardening baseline to the named systemd services.
      Each entry merges the base sandbox options with per-service extraConfig.
    '';
  };

  config.systemd.services = lib.mkMerge (
    lib.mapAttrsToList (
      name: serviceCfg:
      lib.mkIf serviceCfg.enable {
        ${name}.serviceConfig = lib.filterAttrs (_: v: v != null) (
          baseHardening // serviceCfg.extraConfig
        );
      }
    ) cfg
  );
}
```

- [ ] **Step 2: Run the hardening test to verify it passes**

```bash
nix build '.#checks.x86_64-linux.profile-hardening'
```

Expected: build succeeds, hardening score < 2.0.

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/services/hardened.nix tests/nixos/profile-hardening.nix
git commit -m "feat: add services.hardened NixOS module for systemd sandboxing"
```

---

## Task 3: Wire Module into modules/nixos/default.nix

**Files:**

- Modify: `modules/nixos/default.nix`

- [ ] **Step 1: Add hardened.nix to imports**

Current content of `modules/nixos/default.nix`:

```nix
{ ... }:
{
  imports = [
    ./profiles/base.nix
    ./profiles/desktop.nix
    ./profiles/security.nix
    ./profiles/observability.nix
    ./profiles/user.nix
    ./hardware/nvidia-prime.nix
    ./services/systemd-failure-notify.nix
  ];
}
```

Add `./services/hardened.nix`:

```nix
{ ... }:
{
  imports = [
    ./profiles/base.nix
    ./profiles/desktop.nix
    ./profiles/security.nix
    ./profiles/observability.nix
    ./profiles/user.nix
    ./hardware/nvidia-prime.nix
    ./services/systemd-failure-notify.nix
    ./services/hardened.nix
  ];
}
```

- [ ] **Step 2: Verify flake check still passes**

```bash
nix flake check --no-build 2>&1 | head -20
```

Expected: no evaluation errors.

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/default.nix
git commit -m "feat: wire services.hardened into nixos module set"
```

---

## Task 4: Migrate homeserver-vm

Replace all `commonSandbox //` patterns in homeserver-vm with `services.hardened.<name>`.

**Files:**

- Modify: `hosts/homeserver-vm/default.nix`

Current `commonSandbox //` usage (3 services):

```nix
# vaultwarden
vaultwarden.serviceConfig = commonSandbox // {
  CapabilityBoundingSet = "";
  AmbientCapabilities = "";
  ReadWritePaths = [ "/var/lib/vaultwarden" ];
};

# nginx
nginx.serviceConfig = commonSandbox // {
  CapabilityBoundingSet = "";
  AmbientCapabilities = "";
  ReadWritePaths = [
    "/persist/nginx"
    "/var/cache/nginx"
    "/var/log/nginx"
  ];
};

# syncthing
syncthing.serviceConfig = commonSandbox // {
  CapabilityBoundingSet = "";
  AmbientCapabilities = "";
  ProtectSystem = "full";
  ProtectHome = false;
  ReadWritePaths = [
    "/home/user"
    "/var/lib/syncthing"
    "/persist/sync"
  ];
};
```

- [ ] **Step 1: Remove the let binding and commonSandbox // patterns from systemd.services**

Remove the `let` block at the top:

```nix
# DELETE these two lines:
let
  syncthing = import ../../lib/syncthing.nix;
  commonSandbox = import ../../lib/sandbox.nix;
in
```

Replace with (keeping syncthing import, removing commonSandbox):

```nix
let
  syncthing = import ../../lib/syncthing.nix;
in
```

Replace the `systemd.services` block (remove the three `serviceConfig = commonSandbox //` entries):

```nix
systemd = {
  services = {
    nginx-selfsigned = {
      description = "Generate self-signed certificate for nginx";
      wantedBy = [ "multi-user.target" ];
      before = [ "nginx.service" ];
      unitConfig.ConditionPathExists = "!/persist/nginx/cert.pem";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -keyout /persist/nginx/key.pem -out /persist/nginx/cert.pem -sha256 -days 3650 -nodes -subj '/CN=localhost'";
        ExecStartPost = "${pkgs.coreutils}/bin/chown nginx:nginx /persist/nginx/key.pem /persist/nginx/cert.pem";
      };
    };
  };

  tmpfiles.rules = [
    "d /persist/nginx 0700 nginx nginx -"
    "d /persist/sync 0755 user users -"
    "d /var/lib/syncthing 0700 user users -"
  ];
};
```

Add `services.hardened` block (top-level, alongside the `services` and `systemd` blocks):

```nix
services.hardened = {
  vaultwarden = {
    extraConfig = {
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ReadWritePaths = [ "/var/lib/vaultwarden" ];
    };
  };

  nginx = {
    extraConfig = {
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ReadWritePaths = [
        "/persist/nginx"
        "/var/cache/nginx"
        "/var/log/nginx"
      ];
    };
  };

  syncthing = {
    extraConfig = {
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ProtectSystem = "full";
      ProtectHome = false;
      ReadWritePaths = [
        "/home/user"
        "/var/lib/syncthing"
        "/persist/sync"
      ];
    };
  };
};
```

- [ ] **Step 2: Build homeserver-vm to validate**

```bash
nix build '.#checks.x86_64-linux.invariants-homeserver-vm'
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add hosts/homeserver-vm/default.nix
git commit -m "feat: migrate homeserver-vm services to services.hardened"
```

---

## Task 5: Migrate homeserver

Replace all `commonSandbox //` patterns in homeserver with `services.hardened.<name>`.

**Files:**

- Modify: `hosts/homeserver/default.nix`

Current usage (4 services): `tailscale-cert`, `nginx`, `vaultwarden`, `syncthing`.

- [ ] **Step 1: Remove commonSandbox from let binding**

Remove:

```nix
  commonSandbox = import ../../lib/sandbox.nix;
```

Keep the rest of the `let` block (`network`, `tailnetFQDN`, `syncthing`).

- [ ] **Step 2: Remove serviceConfig = commonSandbox // entries from systemd.services**

The `systemd.services` block currently has 4 `serviceConfig = commonSandbox // { ... }` entries. Remove all of them. What remains in `systemd.services` is only the service wiring (`after`, `requires`, `script`, `serviceConfig.Type`, etc.) without sandbox options:

```nix
systemd = {
  network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "yes";
    };
  };

  services = {
    tailscale-cert = {
      description = "Fetch TLS certificate from Tailscale";
      wantedBy = [ "multi-user.target" ];
      after = [
        "tailscaled.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      script = ''
        until ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1; do
          sleep 1
        done
        ${pkgs.tailscale}/bin/tailscale cert --cert-file /var/lib/tailscale/certs/homeserver.crt --key-file /var/lib/tailscale/certs/homeserver.key ${tailnetFQDN}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    nginx = {
      after = [ "tailscale-cert.service" ];
      requires = [ "tailscale-cert.service" ];
    };
  };

  tmpfiles.rules = [
    "d /persist/sync 0755 user users -"
    "d /var/lib/syncthing 0700 user users -"
  ];
};
```

- [ ] **Step 3: Add services.hardened block**

Add alongside the `services` and `systemd` blocks:

```nix
services.hardened = {
  tailscale-cert = {
    extraConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ProtectHome = false;
      ReadWritePaths = [ "/var/lib/tailscale" ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };

  nginx = {
    extraConfig = {
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      ReadWritePaths = [
        "/var/cache/nginx"
        "/var/log/nginx"
      ];
    };
  };

  vaultwarden = {
    extraConfig = {
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ReadWritePaths = [ "/var/lib/vaultwarden" ];
    };
  };

  syncthing = {
    extraConfig = {
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ProtectSystem = "full";
      ProtectHome = false;
      ReadWritePaths = [
        "/home/user"
        "/var/lib/syncthing"
        "/persist/sync"
      ];
    };
  };
};
```

Note: `tailscale-cert` previously had `serviceConfig = commonSandbox // { Type = "oneshot"; RemainAfterExit = true; ProtectHome = false; ReadWritePaths = ...; RestrictAddressFamilies = ...; }`. The `Type` and `RemainAfterExit` now live in `services.hardened.tailscale-cert.extraConfig` since they are `serviceConfig` fields. The base sandbox's `RestrictAddressFamilies` is overridden to `[ "AF_UNIX" ]` (tailscale-cert doesn't need inet).

- [ ] **Step 4: Build homeserver to validate**

```bash
nix build '.#checks.x86_64-linux.invariants-homeserver'
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add hosts/homeserver/default.nix
git commit -m "feat: migrate homeserver services to services.hardened"
```

---

## Task 6: Migrate main

Replace `hwDaemonSandbox` and all custom service sandbox configs in `hosts/main/default.nix` with `services.hardened.<name>`.

**Files:**

- Modify: `hosts/main/default.nix`

**Service analysis:**

| Service                 | Differences from base sandbox                                                                                                                                                                    | Strategy                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| `thermald`              | No PrivateDevices, no SystemCallFilter, adds ProtectProc="invisible" + ProcSubset="pid", RestrictAddressFamilies=["AF_UNIX"] only                                                                | `extraConfig` with null to disable + additions |
| `power-profiles-daemon` | Same as thermald                                                                                                                                                                                 | Same                                           |
| `fwupd`                 | No PrivateDevices, no ProtectSystem, no ProtectKernelTunables, no ProtectKernelModules, no ProtectClock, no MemoryDenyWriteExecute, no SystemCallFilter, RestrictAddressFamilies adds AF_NETLINK | Multiple nulls + different AF list             |
| `bluetooth`             | No PrivateDevices, no ProtectKernelModules, RestrictAddressFamilies=["AF_UNIX", "AF_BLUETOOTH", "AF_NETLINK"]                                                                                    | nulls + different AF list                      |

- [ ] **Step 1: Remove hwDaemonSandbox let binding**

Remove these lines from the `let` block:

```nix
  hwDaemonSandbox = {
    # System hardening for hardware daemons (thermald, ppd). ...
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    ProtectClock = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    MemoryDenyWriteExecute = true;
    LockPersonality = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    SystemCallArchitectures = "native";
  };
```

If nothing else remains in `let`, remove the `let ... in` block entirely and keep only the `network` and `tailnetFQDN` binding.

- [ ] **Step 2: Replace serviceConfig assignments in systemd.services**

Current `systemd.services` block has entries for thermald, ppd, prometheus, opentelemetry-collector, fwupd, bluetooth. Remove the sandbox-related `serviceConfig` lines from thermald, ppd, fwupd, and bluetooth. Keep non-sandbox config unchanged.

Replace entire `systemd.services` block with:

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

- [ ] **Step 3: Add services.hardened block**

Add alongside the `services` and `systemd` blocks:

```nix
services.hardened = {
  # Hardware daemons: need /sys writes via dbus, no network, no private devices.
  # Skip PrivateDevices (/sys access), SystemCallFilter (broad hw access needed).
  thermald = {
    extraConfig = {
      PrivateDevices = null;
      SystemCallFilter = null;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };

  power-profiles-daemon = {
    extraConfig = {
      PrivateDevices = null;
      SystemCallFilter = null;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };

  # fwupd: writes firmware to hardware and loads kernel modules.
  # Skip ProtectSystem (firmware writes), PrivateDevices (/dev access),
  # ProtectKernelModules/Tunables (capsule loading), ProtectClock (EFI time),
  # MemoryDenyWriteExecute (plugin loading), SystemCallFilter (broad hw access).
  fwupd = {
    extraConfig = {
      PrivateDevices = null;
      ProtectSystem = null;
      ProtectKernelTunables = null;
      ProtectKernelModules = null;
      ProtectClock = null;
      MemoryDenyWriteExecute = null;
      SystemCallFilter = null;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
  };

  # bluetoothd: needs AF_BLUETOOTH + AF_NETLINK for HCI management.
  # Skip PrivateDevices (/dev/hci*), ProtectKernelModules (hci module loading).
  bluetooth = {
    extraConfig = {
      PrivateDevices = null;
      ProtectKernelModules = null;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_BLUETOOTH"
        "AF_NETLINK"
      ];
    };
  };
};
```

- [ ] **Step 4: Build main to validate**

```bash
nix build '.#checks.x86_64-linux.invariants-main'
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add hosts/main/default.nix
git commit -m "feat: migrate main host services to services.hardened"
```

---

## Task 7: Remove lib/sandbox.nix

`lib/sandbox.nix` is no longer imported anywhere after Tasks 4–6 and the test update in Task 1.

**Files:**

- Delete: `lib/sandbox.nix`

- [ ] **Step 1: Verify no remaining references**

```bash
grep -r "sandbox.nix" . --include="*.nix"
```

Expected: no output.

- [ ] **Step 2: Delete lib/sandbox.nix**

```bash
git rm lib/sandbox.nix
```

- [ ] **Step 3: Full flake check to validate**

```bash
nix flake check --no-build
```

Expected: no evaluation errors.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: remove lib/sandbox.nix superseded by services.hardened module"
```

---

## Task 8: Final Validation

- [ ] **Step 1: Build all host invariant checks**

```bash
nix build \
  '.#checks.x86_64-linux.invariants-main' \
  '.#checks.x86_64-linux.invariants-homeserver-vm' \
  '.#checks.x86_64-linux.invariants-homeserver'
```

Expected: all three succeed.

- [ ] **Step 2: Run hardening score test**

```bash
nix build '.#checks.x86_64-linux.profile-hardening'
```

Expected: passes with score < 2.0.

- [ ] **Step 3: Lint**

```bash
statix check . && deadnix .
```

Expected: no warnings.
