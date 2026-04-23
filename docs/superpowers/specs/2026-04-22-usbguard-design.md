# USBGuard Configuration for Main Machine

**Date:** 2026-04-22  
**Status:** Design approved  
**Scope:** Enable USB device whitelisting on main machine with implicit deny policy

## Problem

The main machine accepts any USB device by default. This allows:

- **BadUSB attacks**: Malicious USB firmware can emulate keyboards/network adapters
- **Data exfiltration**: Compromised system could leak data via unknown USB devices
- **Supply chain attacks**: Unknown or found USB devices could contain malware

## Solution

Enable USBGuard with an explicit whitelist policy:

- Implicit deny: all USB devices blocked by default
- Explicit whitelist: only known, trusted devices allowed
- Runtime override: unknown devices can be temporarily allowed with CLI (`usbguard allow-device`) if needed

## Configuration Details

### Scope

- **Host:** main machine only
- **Location:** `hosts/main/default.nix` (inline, ~25 lines)
- **Devices whitelisted initially:** Logitech mouse (vendor:product 046d:c54d)
- **Future devices:** USB hub/extender, known USB sticks (added by looking up `lsusb` output and adding rules to config)

### Device Whitelist Rules

```
# Allow Logitech USB Receiver (mouse)
allow id 046d:c54d
```

Additional devices added as:

```
# allow id <vendor>:<product>
```

### Runtime Behavior

- Plugging in a whitelisted device: works normally
- Plugging in unknown device: automatically rejected, appears in `usbguard list-devices` as "blocked"
- Temporarily allowing unknown device: `usbguard allow-device <device-id>` (resets on reboot)
- Permanently allowing: add rule to config, rebuild

### How to Add New Devices

1. Plug in the device
2. Run `lsusb` and find the line: `Bus XXX Device YYY: ID <vendor>:<product> Device Name`
3. Extract `<vendor>:<product>`
4. Add to flake: `allow id <vendor>:<product>` comment with device name
5. Rebuild: `nh os switch --hostname main .`

## Testing

After initial rebuild:

- Verify mouse works: `usbguard list-devices` should show mouse as "allowed"
- Verify blocking: plug in untrusted device, confirm it doesn't enumerate

## Future Extensions

- Add USB hub/extender when connected (expected soon)
- Add known USB sticks as they're identified
- If scope grows (multiple hosts, complex rules), extract to `modules/nixos/profiles/usbguard.nix`

## Threat Model

**Mitigates:**

- BadUSB firmware attacks (malicious keyboard/network emulation)
- Accidental use of unknown USB devices
- Data exfiltration via connected USB sticks

**Does not mitigate:**

- Physical DMA attacks (Thunderbolt, PCIe) — already mitigated by IOMMU on main
- Supply chain compromise of whitelisted devices (rare, requires physical access + pre-compromise)

## Non-Goals

- AppArmor profiles on homeserver (already strong systemd sandboxing)
- fail2ban tuning for homeserver (deferred until hardware deployed)
