# Initrd SSH Exposure: Risk Model & Constraints

**Date:** 2026-04-23
**Scope:** `hosts/main` only
**Approach:** Documentation + flush-before-stage2 (defense-in-depth)

---

## Background

`main` enables initrd SSH on port 2222 as a fallback LUKS unlock path when TPM2 fails.
An audit confirmed exposure is conditional — reachability depends on boot-time network
setup — but raised the question of whether public WiFi boot scenarios create meaningful risk.

## Findings

- **WiFi is unavailable in initrd.** Stage 1 has no WiFi drivers or WPA supplicant. Port
  2222 is only reachable via wired Ethernet.
- **Recovery requires a USB Ethernet dongle.** Without one, initrd SSH cannot be used.
- **Public WiFi exposure is not a real concern.** The machine cannot get a network address
  over WiFi in stage 1.
- **No subnet restrictions are feasible.** The machine is WiFi-only; boot network topology
  varies (home, public, hotspot). Source-IP whitelisting is impractical.
- **Primary protection is key-based auth.** Authorized keys are sourced from
  `lib/pubkeys.nix`; host key is sops-managed.
- **Recovery path is untested.** No dongle currently owned; recovery has never been
  exercised end-to-end.

## Design

### 1. flush-network-before-stage2 service

A oneshot systemd unit added to `boot.initrd.systemd.services` in `hosts/main/default.nix`.

**Ordering:** `Before = initrd-cleanup.service`, `WantedBy = initrd.target`
`DefaultDependencies = false` to avoid circular ordering in initrd.

**Effect:** Iterates all non-loopback interfaces from `/sys/class/net/*`, brings each down
(`ip link set dev $iface down`), and flushes addresses (`ip addr flush dev $iface`).
`iproute2` is included automatically when `boot.initrd.network.enable = true`.

**Why:** Ensures port 2222 stops being reachable the moment stage 1 is done, before stage
2's firewall loads. Guards against future misconfiguration (e.g., if WiFi support were
added to initrd later).

### 2. Documentation comment

Added above the `initrd.network` block in `hosts/main/default.nix`:

```
# Initrd SSH — fallback LUKS unlock when TPM2 fails.
# Recovery requires a USB Ethernet dongle; WiFi is not available in stage 1.
# Port 2222 is therefore NOT exposed on WiFi (including public WiFi).
# flush-network-before-stage2 tears down the interface before stage 2 starts.
```

### 3. GOALS.md

P1 task marked complete with findings and an operational follow-up note to acquire a
USB-C Ethernet dongle and test recovery end-to-end before relying on it in an emergency.

## Files Changed

- `hosts/main/default.nix` — new systemd service + comment block
- `GOALS.md` — P1 task resolved

## Out of Scope

- Other hosts (homeserver, homeserver-vm, vm) — no initrd SSH configured there
- Subnet-based firewall rules — impractical given variable boot network topology
- WiFi-in-initrd support — not needed; dongle is the recovery path
