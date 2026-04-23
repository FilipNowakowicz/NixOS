# KVM Availability Fail-Fast in Smoke Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit `/dev/kvm` availability checks to both smoke tests so they fail immediately with actionable error messages instead of hanging indefinitely.

**Architecture:** Each test's Python script gets an `import os` statement and an assertion before `start_all()` that checks for `/dev/kvm` existence. Identical checks in both tests ensure consistent behavior.

**Tech Stack:** NixOS testing-python framework, Python assertions

---

### Task 1: Add KVM Check to vm-smoke.nix

**Files:**

- Modify: `tests/nixos/vm-smoke.nix:54-62`

- [ ] **Step 1: Update testScript with KVM availability check**

Open `tests/nixos/vm-smoke.nix` and replace the `testScript` section:

```nix
    testScript = ''
      import os
      assert os.path.exists('/dev/kvm'), \
        "KVM not available: /dev/kvm missing. Smoke tests require KVM acceleration.\n" \
        "On Linux: enable nested KVM or run on hardware with KVM support.\n" \
        "On WSL: upgrade to WSL2 with --system-distro support or use nested hypervisor."

      start_all()

      vm.wait_for_unit("multi-user.target")
      vm.wait_for_unit("systemd-logind.service")
      vm.wait_for_unit("NetworkManager.service")
      vm.wait_for_unit("dbus.service")
    '';
```

- [ ] **Step 2: Verify the syntax**

Run: `nix flake check`

Expected: No errors, flake passes validation.

- [ ] **Step 3: Commit the change**

```bash
git add tests/nixos/vm-smoke.nix
git commit -m "test: add KVM availability check to vm-smoke test"
```

---

### Task 2: Add KVM Check to homeserver-vm-smoke.nix

**Files:**

- Modify: `tests/nixos/homeserver-vm-smoke.nix:48-76`

- [ ] **Step 1: Update testScript with KVM availability check**

Open `tests/nixos/homeserver-vm-smoke.nix` and replace the `testScript` section:

```nix
    testScript = ''
      import os
      assert os.path.exists('/dev/kvm'), \
        "KVM not available: /dev/kvm missing. Smoke tests require KVM acceleration.\n" \
        "On Linux: enable nested KVM or run on hardware with KVM support.\n" \
        "On WSL: upgrade to WSL2 with --system-distro support or use nested hypervisor."

      start_all()

      homeserver.wait_for_unit("multi-user.target")
      homeserver.wait_for_unit("vaultwarden.service")
      homeserver.wait_for_unit("nginx.service")
      homeserver.wait_for_unit("syncthing.service")
      homeserver.wait_for_unit("grafana.service")
      homeserver.wait_for_unit("loki.service")
      homeserver.wait_for_unit("tempo.service")
      homeserver.wait_for_unit("mimir.service")
      homeserver.wait_for_unit("prometheus.service")
      homeserver.wait_for_unit("prometheus-node-exporter.service")
      homeserver.wait_for_unit("alloy.service")
      homeserver.wait_for_unit("opentelemetry-collector.service")

      # Validate nginx TLS proxy to Vaultwarden.
      homeserver.succeed("curl -kfsS https://127.0.0.1:8443/ | grep -Eqi 'vaultwarden|bitwarden'")

      # Validate Syncthing GUI bind.
      homeserver.succeed("ss -ltn '( sport = :8384 )' | grep -q 127.0.0.1:8384")

      # Validate observability endpoints.
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:3000/api/health | grep -q '\"database\"[[:space:]]*:[[:space:]]*\"ok\"'")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:3100/ready")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:3200/ready")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:9009/ready")
      homeserver.wait_until_succeeds("curl -fsS http://127.0.0.1:9090/-/ready")
    '';
```

- [ ] **Step 2: Verify the syntax**

Run: `nix flake check`

Expected: No errors, flake passes validation.

- [ ] **Step 3: Commit the change**

```bash
git add tests/nixos/homeserver-vm-smoke.nix
git commit -m "test: add KVM availability check to homeserver-vm-smoke test"
```

---

## Self-Review

**Spec coverage:**

- ✓ KVM check in vm-smoke.nix before start_all()
- ✓ KVM check in homeserver-vm-smoke.nix before start_all()
- ✓ Import os statement
- ✓ Assertion with multi-line error message covering Linux/WSL remediation

**Placeholder scan:** No TBD, TODO, or vague steps. All code is complete and exact.

**Type consistency:** Both tests use identical assertion logic and error message.
