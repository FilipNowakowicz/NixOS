# Secure Firefox Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `firefox-private` command that launches a truly ephemeral, hardened Firefox session.

**Architecture:** A `writeShellApplication` wrapper creates a fresh temp profile on each launch, injects a hardened `user.js` from the Nix store, launches Firefox with `--profile --no-remote`, and wipes the profile directory on exit via `trap`. No new modules, no impact on daily Firefox.

**Tech Stack:** Nix, home-manager, Firefox, bash (`writeShellApplication`)

---

## Files

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `home/files/firefox/private-user.js` | All hardened Firefox prefs |
| Modify | `home/users/user/home.nix` | Add `firefox-private` to `home.packages` |

---

### Task 1: Create the hardened `user.js`

**Files:**
- Create: `home/files/firefox/private-user.js`

- [ ] **Step 1: Create `home/files/firefox/private-user.js`**

```javascript
// Fingerprinting resistance
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.fingerprintingProtection", true);

// Tracking protection
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("network.cookie.cookieBehavior", 1);

// WebRTC leak fix
user_pref("media.peerconnection.enabled", false);

// DNS leak fix — let VPN handle DNS, disable Firefox's own DoH
user_pref("network.trr.mode", 5);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);

// Telemetry / phoning home
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("geo.enabled", false);
user_pref("browser.send_pings", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);

// Session / history
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("browser.sessionstore.privacy_level", 2);
```

- [ ] **Step 2: Verify the file exists**

```bash
cat home/files/firefox/private-user.js
```

Expected: file contents printed, no error.

- [ ] **Step 3: Commit**

```bash
git add home/files/firefox/private-user.js
git commit -m "feat: add hardened user.js for private Firefox profile"
```

---

### Task 2: Add `firefox-private` launcher to home.nix

**Files:**
- Modify: `home/users/user/home.nix`

- [ ] **Step 1: Add `privateUserJs` to the existing `let` block and add the `firefox-private` package**

The existing `let` block at the top of `home/users/user/home.nix` currently reads:

```nix
let
  nixRepo = "${config.home.homeDirectory}/nix";
in
```

Extend it and add the new `writeShellApplication` entry to `home.packages`, after the existing `clipboard-pick` entry:

```nix
let
  nixRepo = "${config.home.homeDirectory}/nix";
  privateUserJs = ../../files/firefox/private-user.js;
in
```

Then add to `home.packages`:

```nix
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

- [ ] **Step 2: Validate the Nix expression builds**

```bash
nh os build --hostname main .
```

Expected: build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add home/users/user/home.nix
git commit -m "feat: add firefox-private ephemeral hardened browser command"
```

---

### Task 3: Deploy and verify

- [ ] **Step 1: Deploy to main**

```bash
nh os switch --hostname main .
```

Expected: switch completes, no errors.

- [ ] **Step 2: Verify the command is on PATH**

```bash
which firefox-private
```

Expected: `/home/user/.nix-profile/bin/firefox-private` or similar Nix store path.

- [ ] **Step 3: Smoke test — launch and verify temp profile**

```bash
firefox-private &
# In another terminal, while Firefox is open:
ls /tmp/ | grep tmp
```

Expected: a `tmp.XXXXXX` directory exists while Firefox is running. After closing Firefox, it should be gone.

- [ ] **Step 4: Verify privacy settings loaded**

Open `about:config` in the private browser and confirm:
- `privacy.resistFingerprinting` → `true`
- `media.peerconnection.enabled` → `false`
- `network.trr.mode` → `5`
