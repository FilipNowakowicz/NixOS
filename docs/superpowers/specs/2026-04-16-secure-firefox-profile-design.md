# Secure Firefox Profile Design

**Date:** 2026-04-16
**Status:** Approved

## Goal

Add a `firefox-private` command that launches a truly ephemeral, hardened Firefox session for anonymous, untrusted, throwaway browsing. The session leaves no trace after closing and does not interfere with the existing daily Firefox setup.

---

## Use Case

- Browsing untrusted or sketchy sites
- Anonymous sessions where no accounts are used
- Throwaway browsing where nothing persists between sessions

With a VPN layered on top, this setup provides solid protection against casual tracking and IP-based identification. It is not Tor-level anonymity but is appropriate for the stated use case.

---

## Components

### `home/files/firefox/private-user.js`

A raw Firefox `user.js` file stored in the Nix store. Contains all hardened privacy preferences (see settings below). Read via `builtins.readFile` and copied into the temp profile on each launch.

### `firefox-private` (shell script via `writeShellApplication`)

Declared in `home/users/user/home.nix` inside `home.packages`. Launch sequence:

1. `mktemp -d` — creates a fresh profile directory under `/tmp`
2. Copies `private-user.js` from the Nix store into `<tmpdir>/user.js`
3. `trap 'rm -rf "$profile"' EXIT` — profile is wiped on Firefox close, including crashes
4. `exec firefox --profile "$profile" --no-remote "$@"`

`--no-remote` prevents the command from hijacking an existing normal Firefox window.

---

## Privacy Settings (`user.js`)

### Fingerprinting resistance
- `privacy.resistFingerprinting = true` — spoofs timezone (UTC), disables canvas/WebGL fingerprinting, normalises screen metrics
- `privacy.fingerprintingProtection = true` — additional protections in newer Firefox

### Tracking protection
- `privacy.trackingprotection.enabled = true`
- `privacy.trackingprotection.socialtracking.enabled = true`
- `privacy.trackingprotection.fingerprinting.enabled = true`
- `privacy.trackingprotection.cryptomining.enabled = true`
- `network.cookie.cookieBehavior = 1` — block third-party cookies

### WebRTC leak fix
- `media.peerconnection.enabled = false` — disables WebRTC entirely; prevents local IP leakage through VPN

### DNS leak fix
- `network.trr.mode = 5` — disables Firefox's built-in DNS-over-HTTPS; lets VPN handle all DNS
- `network.dns.disablePrefetch = true`
- `network.prefetch-next = false`

### Telemetry / phoning home
- `toolkit.telemetry.enabled = false`
- `toolkit.telemetry.unified = false`
- `datareporting.healthreport.uploadEnabled = false`
- `browser.safebrowsing.malware.enabled = false` — Safe Browsing sends URL hashes to Google; disabled for anonymity
- `browser.safebrowsing.phishing.enabled = false`
- `geo.enabled = false`
- `browser.send_pings = false`
- `browser.urlbar.speculativeConnect.enabled = false`

### Session / history
- `privacy.sanitize.sanitizeOnShutdown = true` — belt-and-suspenders on top of temp profile wipe
- `browser.sessionstore.privacy_level = 2`

---

## Video Playback

JavaScript is enabled. `privacy.resistFingerprinting` may break some sites (timezone mismatch, canvas blocked). If a site breaks, the user can toggle `privacy.resistFingerprinting` off in `about:config` for that session — it does not persist since the profile is ephemeral.

---

## File Placement

| File | Change |
|------|--------|
| `home/files/firefox/private-user.js` | New file — hardened user.js prefs |
| `home/users/user/home.nix` | Add `firefox-private` to `home.packages` |

No new modules. No changes to existing Firefox setup. Daily `firefox` is unaffected.

---

## Implementation Sketch

```nix
let
  privateUserJs = ../../files/firefox/private-user.js;
in
(writeShellApplication {
  name = "firefox-private";
  runtimeInputs = [ pkgs.firefox ];
  text = ''
    profile=$(mktemp -d)
    trap 'rm -rf "$profile"' EXIT
    cp ${privateUserJs} "$profile/user.js"
    exec firefox --profile "$profile" --no-remote "$@"
  '';
})
```

---

## Out of Scope

- Enterprise policy (`DisableDownloads`) — not required; downloads disappear with the profile on close
- Tor routing — not a goal; VPN handles IP masking
- Persistent hardened profile — can be revisited if ephemeral proves inconvenient
- Hyprland keybind — not requested; `firefox-private` command is sufficient
