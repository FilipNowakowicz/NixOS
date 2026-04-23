# Tailscale Cert Service Timeout — Design Spec

**Date:** 2026-04-23  
**Scope:** Add timeout to `tailscale-cert.service` to prevent infinite polling when Tailscale is unhealthy.

---

## Problem Statement

The `tailscale-cert.service` on the homeserver uses an infinite `until` loop to wait for Tailscale to be ready:

```bash
until ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1; do
  sleep 1
done
```

If Tailscale is unhealthy or unresponsive during boot, this loop hangs forever, blocking nginx startup and making the homeserver inaccessible. This is a boot reliability issue: the operator has no explicit signal that something is wrong.

---

## Design

### 1. Service Configuration: Add TimeoutStartSec

Add a 60-second startup timeout to the systemd service:

```nix
serviceConfig = {
  Type = "oneshot";
  RemainAfterExit = true;
  TimeoutStartSec = 60;  # Fail if not complete within 60 seconds
};
```

**Rationale:**

- Systemd will forcibly terminate the service after 60 seconds if it hasn't exited.
- The service will fail, which blocks nginx (it has `requires = [ "tailscale-cert.service" ]`).
- Explicit failure is better than silent hanging; the operator sees a clear error in `systemctl status` and logs.

**Timeout duration (60s):**

- Normal Tailscale startup on the homeserver: 5–10 seconds.
- Slow first-boot or network variance: 20–30 seconds.
- 60 seconds provides headroom without being excessive.

### 2. Script Bounded Retry: Replace Infinite Loop

Replace the infinite `until` loop with a bounded retry:

```bash
for attempt in {1..60}; do
  ${pkgs.tailscale}/bin/tailscale status > /dev/null 2>&1 && break
  [ $attempt -lt 60 ] && sleep 1
done
```

**Rationale:**

- Attempts to reach Tailscale once per second for a maximum of 60 seconds.
- Exits the loop immediately on success (no unnecessary sleep after the last attempt).
- If it fails, the script continues to the cert fetch, which will fail gracefully if Tailscale is unavailable.
- This dual-layer approach (script timeout + systemd timeout) ensures the service doesn't hang even if the loop has a subtle bug.

### 3. Failure Behavior

If Tailscale is unavailable after 60 seconds:

1. The script finishes the cert fetch (which will error if Tailscale is unreachable).
2. Systemd's `TimeoutStartSec` triggers after 60 seconds, forcing the service to fail.
3. Nginx doesn't start (it `requires` this service).
4. The operator sees a clear failure: `systemctl status microvm@homeserver-vm.service` shows the timeout.
5. Operator debugs: `journalctl -u tailscale-cert.service -n 20` reveals the issue.

---

## Files Changed

- `hosts/homeserver/default.nix`
  - Line 63: Add `TimeoutStartSec = 60;` to `serviceConfig`
  - Lines 56–60: Replace infinite `until` loop with bounded `for` loop

---

## Testing & Verification

1. **Normal boot:** Verify nginx starts normally when Tailscale is healthy.
2. **Tailscale delay:** Simulate slow Tailscale startup (e.g., restart Tailscale mid-boot) and verify the service recovers.
3. **Tailscale unavailable:** Stop Tailscale before boot and verify:
   - Service times out after ~60 seconds.
   - Systemd shows the service as failed.
   - `journalctl` logs show the timeout clearly.
   - Nginx does not start (expected behavior).
4. **Cert persistence:** Verify the cert is fetched and persisted correctly on successful boots.

---

## Success Criteria

- ✅ Service fails explicitly (not hangs) if Tailscale is unavailable.
- ✅ Service completes quickly on normal boots (no artificial delays).
- ✅ Nginx only starts after cert is successfully fetched.
- ✅ Operator can diagnose failures from systemd logs.

---

## Risks & Mitigations

| Risk                                                 | Mitigation                                                                                                            |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Timeout is too short for slow systems                | 60s is conservative; normal startup is 5–10s. First boot with network delays should fit within 60s.                   |
| Breaking change to boot behavior                     | This only affects unhealthy Tailscale scenarios (which are currently broken anyway). Normal boots are unaffected.     |
| Cert not fetched if Tailscale is briefly unavailable | Script bounded retry (60 attempts × 1s) gives Tailscale time to recover. If it doesn't, the service fails (expected). |

---

## Deployment Notes

- No configuration changes needed on the operator side.
- No change to the homeserver's sops secrets or runtime behavior (healthy Tailscale path is identical).
- Homeserver-vm uses a self-signed cert, not this service; unaffected.
