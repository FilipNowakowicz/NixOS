---
name: KVM Availability Fail-Fast in Smoke Tests
description: Add explicit /dev/kvm checks to smoke tests to fail immediately with actionable error messages instead of hanging indefinitely
type: spec
---

# KVM Availability Fail-Fast in Smoke Tests

## Problem

Smoke tests (`vm-smoke` and `homeserver-vm-smoke`) require KVM acceleration to run. When `/dev/kvm` is missing, QEMU hangs indefinitely during `start_all()`, causing the test to timeout with a confusing error message. This is particularly problematic in CI environments or when running tests on systems where KVM isn't available.

## Solution

Add an explicit KVM availability check at the start of each test's Python test script. The check fails immediately with a clear, actionable error message before any VM startup is attempted.

## Design

### Changes

**File:** `tests/nixos/vm-smoke.nix`

In the `testScript` section, add a KVM availability check before `start_all()`:

```python
import os
assert os.path.exists('/dev/kvm'), \
  "KVM not available: /dev/kvm missing. Smoke tests require KVM acceleration.\n" \
  "On Linux: enable nested KVM or run on hardware with KVM support.\n" \
  "On WSL: upgrade to WSL2 with --system-distro support or use nested hypervisor."
start_all()
```

**File:** `tests/nixos/homeserver-vm-smoke.nix`

Apply the identical check to the `testScript` section before `start_all()`.

### Behavior

- **Success case:** `/dev/kvm` exists → check passes silently, test proceeds as normal
- **Failure case:** `/dev/kvm` missing → assertion fails immediately with clear error message, test exits with non-zero status

### Error Message

The error message provides:

1. **Problem statement:** "KVM not available: /dev/kvm missing"
2. **Requirement:** "Smoke tests require KVM acceleration"
3. **Platform-specific remediation:**
   - Linux: enable nested KVM or use hardware with KVM
   - WSL: upgrade to WSL2 with proper configuration

### Testing

- Verify check passes on systems with `/dev/kvm`
- Verify check fails with clear message on systems without `/dev/kvm`
- Both smoke tests should behave identically

## Rationale

- **Fail-fast:** Detects missing KVM in ~1 second instead of after hanging for minutes
- **Clear feedback:** Error message is immediately visible in test output
- **Minimal complexity:** Single assertion per test, no abstraction overhead
- **Consistent:** Both smoke tests receive identical treatment
