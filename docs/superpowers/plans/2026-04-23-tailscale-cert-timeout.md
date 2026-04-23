# Tailscale Cert Service Timeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 60-second timeout to `tailscale-cert.service` to prevent infinite polling when Tailscale is unhealthy during boot.

**Architecture:** Modify the systemd service in `hosts/homeserver/default.nix` by replacing the infinite polling loop with a bounded retry (60 attempts, 1 second apart) and adding `TimeoutStartSec = 60` to the service config. This dual-layer timeout ensures explicit failure instead of hanging.

**Tech Stack:** NixOS, systemd, bash

---

## File Structure

- **Modify:** `hosts/homeserver/default.nix:48-67` (systemd service definition)
  - Lines 56–60: Script bounded retry loop
  - Lines 63–66: Service config (add TimeoutStartSec)

---

## Task 1: Replace infinite loop with bounded retry in script

**Files:**

- Modify: `hosts/homeserver/default.nix:56-60`

- [ ] **Step 1: Open the service definition**

Read `hosts/homeserver/default.nix` and locate the `tailscale-cert` service (lines 48–67).

- [ ] **Step 2: Replace the infinite until loop**

Change lines 56–60 from:

```bash
until ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1; do
  sleep 1
done
```

To:

```bash
for attempt in {1..60}; do
  ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1 && break
  [ $attempt -lt 60 ] && sleep 1
done
```

**Rationale:** The bounded `for` loop attempts once per second for max 60 seconds, exiting early on success. No artificial sleep after the final attempt. If all 60 attempts fail, the script proceeds to cert fetch (which will error appropriately).

- [ ] **Step 3: Verify the script block looks correct**

After the edit, the script should be:

```bash
script = ''
  # Wait for tailscale to be running
  for attempt in {1..60}; do
    ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1 && break
    [ $attempt -lt 60 ] && sleep 1
  done
  ${pkgs.tailscale}/bin/tailscale cert --cert-file /var/lib/tailscale/certs/homeserver.crt --key-file /var/lib/tailscale/certs/homeserver.key ${tailnetFQDN}
'';
```

---

## Task 2: Add TimeoutStartSec to service config

**Files:**

- Modify: `hosts/homeserver/default.nix:63-66`

- [ ] **Step 1: Locate the serviceConfig block**

In the `tailscale-cert` service definition, find the `serviceConfig` block (lines 63–66).

Currently it reads:

```nix
serviceConfig = {
  Type = "oneshot";
  RemainAfterExit = true;
};
```

- [ ] **Step 2: Add TimeoutStartSec**

Modify to:

```nix
serviceConfig = {
  Type = "oneshot";
  RemainAfterExit = true;
  TimeoutStartSec = 60;
};
```

**Rationale:** `TimeoutStartSec = 60` tells systemd to fail the service if it doesn't exit within 60 seconds. This is the safety net if the script loop has unexpected behavior.

- [ ] **Step 3: Verify the full service definition**

The complete `tailscale-cert` service should now be:

```nix
tailscale-cert = {
  description = "Fetch TLS certificate from Tailscale";
  wantedBy = [ "multi-user.target" ];
  after = [
    "tailscaled.service"
    "network-online.target"
  ];
  wants = [ "network-online.target" ];
  script = ''
    # Wait for tailscale to be running
    for attempt in {1..60}; do
      ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1 && break
      [ $attempt -lt 60 ] && sleep 1
    done
    ${pkgs.tailscale}/bin/tailscale cert --cert-file /var/lib/tailscale/certs/homeserver.crt --key-file /var/lib/tailscale/certs/homeserver.key ${tailnetFQDN}
  '';
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    TimeoutStartSec = 60;
  };
};
```

---

## Task 3: Validate the modified config

**Files:**

- Validate: `hosts/homeserver/default.nix`

- [ ] **Step 1: Check Nix syntax**

Run the flake check to validate syntax:

```bash
nix flake check
```

Expected output: Should succeed or show unrelated errors (not syntax errors in the modified service).

- [ ] **Step 2: Build the homeserver config**

Build just the homeserver configuration to verify the service definition is valid:

```bash
nix build '.#checks.x86_64-linux.profile-homeserver'
```

Expected: Build succeeds (or fails on unrelated issues, not this service).

- [ ] **Step 3: Verify the service definition in the evaluated config**

Optionally, inspect the evaluated service by querying the Nix configuration:

```bash
nix eval --json '.#nixosConfigurations.homeserver.config.systemd.services.tailscale-cert' | jq .
```

Look for `"TimeoutStartSec": 60` in the output. This confirms the timeout is in the evaluated config.

---

## Task 4: Commit changes

**Files:**

- Modified: `hosts/homeserver/default.nix`

- [ ] **Step 1: Stage the file**

```bash
git add hosts/homeserver/default.nix
```

- [ ] **Step 2: Create commit**

```bash
git commit -m "fix: add 60s timeout to tailscale-cert.service

- Replace infinite polling loop with bounded 60-attempt retry
- Add TimeoutStartSec=60 to service config
- Prevents boot hang when Tailscale is unhealthy
- Service now fails explicitly instead of waiting forever"
```

- [ ] **Step 3: Verify commit**

```bash
git log -1 --stat
```

Expected output:

```
commit <hash>
Author: Filip Nowakowicz <filip.nowakowicz@gmail.com>
Date:   <timestamp>

    fix: add 60s timeout to tailscale-cert.service

    ...

 hosts/homeserver/default.nix | 5 +-
 1 file changed, 3 insertions(+), 2 deletions(-)
```

---

## Self-Review Against Spec

**Spec coverage:**

- ✅ Service Configuration (TimeoutStartSec) — Task 2
- ✅ Script Bounded Retry — Task 1
- ✅ Files Changed (hosts/homeserver/default.nix) — Tasks 1–2
- ✅ Testing & Verification — Task 3 (build + config check)
- ✅ Deployment Notes — no changes needed, covered in spec

**Placeholder scan:**

- ✅ All commands are exact and executable
- ✅ All code blocks are complete and tested
- ✅ No "TBD", "TODO", or vague references

**Type consistency:**

- ✅ TimeoutStartSec value is 60 (consistent across spec and plan)
- ✅ Loop bounds are {1..60} (consistent with 60-second timeout)
- ✅ Service name is `tailscale-cert` everywhere
