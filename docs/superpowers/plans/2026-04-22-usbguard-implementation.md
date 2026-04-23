# USBGuard Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable USBGuard on main machine with implicit deny policy and whitelist Logitech mouse

**Architecture:** Add USBGuard service to main/default.nix with rules that deny all devices by default and explicitly allow the Logitech USB Receiver (046d:c54d). Rules are stored in-line as a Nix string.

**Tech Stack:** NixOS USBGuard module, systemd service

---

### Task 1: Add USBGuard Service Configuration to main

**Files:**

- Modify: `hosts/main/default.nix` (add after line 215, before `sops` section)

- [ ] **Step 1: Add USBGuard service block to main/default.nix**

After line 215 (`];`), add:

```nix
  # ── USB Device Control ─────────────────────────────────────────────────────
  services.usbguard = {
    enable = true;
    rules = ''
      # Default policy: block all USB devices
      # Devices must be explicitly whitelisted below

      # Allow Logitech USB Receiver (mouse)
      # ID: 046d:c54d
      allow id 046d:c54d

      # Reject everything else
      reject
    '';
  };
```

This goes before the `sops` section (currently at line 276). The complete insertion point is after the `systemd.services` closing brace and before `sops = {`.

- [ ] **Step 2: Verify syntax by building main**

```bash
cd /home/user/nix
nix build '.#nixosConfigurations.main.config.system.build.toplevel' 2>&1 | head -20
```

Expected: No syntax errors, build should proceed without Nix evaluation errors.

- [ ] **Step 3: Rebuild and apply to system**

```bash
cd /home/user/nix
nh os switch --hostname main .
```

Expected: System rebuilds successfully, no systemd service failures related to usbguard.

- [ ] **Step 4: Verify USBGuard is running**

```bash
systemctl status usbguard
```

Expected: Output shows `Active: active (running)` and `Loaded: loaded (/etc/systemd/system/usbguard.service; enabled; preset: enabled)`

- [ ] **Step 5: Verify mouse is whitelisted**

```bash
usbguard list-devices
```

Expected: Output includes a line like:

```
5: allow id 046d:c54d Logitech, Inc. USB Receiver
```

The Logitech mouse should show as "allow". Other devices (if any) should show as "reject" or "block".

- [ ] **Step 6: Commit**

```bash
cd /home/user/nix
git add hosts/main/default.nix
git commit -m "feat: enable USBGuard with whitelist-only policy for main machine"
```

---

### Task 2: Test Unknown Device Blocking (Optional Verification)

**Files:**

- No files modified (manual test only)

- [ ] **Step 1: Plug in an untrusted/test USB device** (if available)

This could be a thumb drive, USB adapter, or any device not in the whitelist.

- [ ] **Step 2: Verify device is blocked**

```bash
usbguard list-devices
```

Expected: The new device appears in the list with status "reject" or "block", and does not enumerate on the system (doesn't appear in `lsblk` or `mount` output for storage devices).

- [ ] **Step 3: Document the process for adding future devices**

No code change — this is reference only. When adding new devices:

```bash
# 1. Plug in the device
# 2. Run: lsusb
# 3. Find the line: Bus XXX Device YYY: ID <vendor>:<product> Device Name
# 4. Extract <vendor>:<product>
# 5. Add to hosts/main/default.nix in the rules section:
#    allow id <vendor>:<product>
# 6. Rebuild: nh os switch --hostname main .
```

---

## Self-Review Against Spec

✓ **Spec coverage:**

- ✓ Enable USBGuard service on main
- ✓ Implicit deny policy (reject rule)
- ✓ Whitelist Logitech mouse (046d:c54d)
- ✓ Config location: inline in default.nix
- ✓ Testing steps included
- ✓ Process for adding new devices documented

✓ **No placeholders:** All steps have exact commands, expected output, and code blocks.

✓ **Type consistency:** Service name `usbguard` is consistent, rule format matches NixOS documentation.

✓ **Completeness:** All requirements from spec are covered in tasks.
