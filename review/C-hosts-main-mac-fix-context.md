# Fix context — Host configs `main` + `mac`

Self-contained instructions for a fix agent. Each item has the exact issue, the
current code, a concrete fix, and a validation command. Apply P0/P1 first.

Repo root: `/home/user/nix`. Deploy `main` with
`nh os switch --hostname main .`; deploy `mac` with `deploy '.#mac'`.

Validation shortcuts (do not run `nix build`/`eval` unless noted — they are
slow; the cheap gate is `flake-eval`):

```bash
bash scripts/validate.sh flake-eval     # nix flake check --no-build
bash scripts/validate.sh host main      # build main closure
bash scripts/validate.sh host mac       # build mac closure
statix check . && deadnix .
```

## Status after PR 62

- `[DONE]` P0-1, P1-1, P1-2, P1-4, and P2-1 landed.
- `[OPEN]` P1-3, P2-2, P2-3, P2-4, P2-5/P2-\* docs-only additions, and P3
  remain open unless covered by separate future work.

---

## P0-1 — Persist fail2ban DB on `mac`

**Issue:** `mac` enables OpenSSH + fail2ban but does not persist
`/var/lib/fail2ban`, so the ban database resets every reboot on the ephemeral
root. `main` persists it; `mac` does not.

**Current** (`hosts/mac/impermanence.nix`):

```nix
  environment.persistence."/persist".directories = [
    "/var/lib/tailscale" # tailnet node identity + peers
    "/var/lib/bluetooth" # Bluetooth pairings
    "/etc/NetworkManager/system-connections" # saved Wi-Fi / VPN profiles
    # systemd state that affects boot-time behavior rather than runtime:
    "/var/lib/systemd/timers"
    "/var/lib/systemd/backlight"
    "/var/lib/systemd/rfkill"
  ];
```

**Fix:** add the fail2ban path (mirror main's comment):

```nix
    "/var/lib/tailscale" # tailnet node identity + peers
    "/var/lib/bluetooth" # Bluetooth pairings
    "/var/lib/fail2ban" # banned-IP database (resets to empty without this)
    "/etc/NetworkManager/system-connections" # saved Wi-Fi / VPN profiles
```

Before first deploy after this change, snapshot live state if the host is up:
`sudo cp -a /var/lib/fail2ban /persist/var/lib/` (otherwise the bind mount lands
on an empty dir, which is fine here since it just starts empty).

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host mac
# After deploy: findmnt /var/lib/fail2ban  # should show a bind from /persist
```

---

## P1-1 — Whonix images: back up or document the omission

**Issue:** `/var/lib/libvirt` (Whonix qcow2 + domain XML) is persisted but not in
restic; disk loss destroys the VMs with no off-host copy, and this is not
documented as intentional.

**Current** (`hosts/main/backups.nix`, `restic.backups.local.paths`): no
`/var/lib/libvirt` entry.

**Fix option A (back up domain definitions only — small, recommended):**

```nix
      paths = [
        # ... existing paths ...
        "/var/lib/libvirt/qemu"   # Whonix domain XML (NOT the multi-GB images)
      ];
```

**Fix option B (document as intentionally excluded):** add to
`hosts/main/CLAUDE.md` under "Whonix KVM":

```md
- **Not backed up to B2**: the qcow2 images are large and re-derivable from the
  upstream Whonix release; only the libvirt domain XML matters and is trivially
  recreated. Disk loss means re-import, not data loss.
```

Pick one. The backup⊆persist invariant (`flake/checks.nix:119`) already passes
for `/var/lib/libvirt` because it is persisted, so option A will not trip it.

**Validate:**

```bash
bash scripts/validate.sh flake-eval     # invariant: backup ⊆ persist
bash scripts/validate.sh host main
```

---

## P1-2 — `network-online.target` ordering is a no-op on `main`

**Issue:** `restic-check-local` (and the restic backup job) order on
`network-online.target`, but `main` disables both wait-online providers, so the
target is reached immediately and the dependency provides no real "wait for
connectivity."

**Current** (`hosts/main/backups.nix`):

```nix
      restic-check-local = {
        description = "Restic workstation repository integrity check";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
```

and (`hosts/main/networking.nix`):

```nix
    "systemd-networkd-wait-online".enable = lib.mkForce false;
    "NetworkManager-wait-online".enable = lib.mkForce false;
```

**Fix (make the dependency real with a bounded reachability probe):**

```nix
      restic-check-local = {
        description = "Restic workstation repository integrity check";
        # network-online.target is a no-op here (wait-online disabled); probe
        # the repo backend directly with a bounded retry instead.
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        environment.RESTIC_PASSWORD_FILE = config.sops.secrets.restic_password.path;
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = pkgs.writeShellScript "restic-check-wait-repo" ''
            for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
              ${pkgs.restic}/bin/restic cat config \
                --repository-file=${config.sops.secrets.restic_repository.path} \
                >/dev/null 2>&1 && exit 0
              ${pkgs.coreutils}/bin/sleep 10
            done
            echo "restic repo unreachable after 5min" >&2
            exit 1
          '';
          # ... existing ExecStart / ExecStartPost / EnvironmentFile ...
        };
      };
```

(`restic cat config` needs the password+B2 env; the existing `environment` and
`EnvironmentFile` already supply them.) Minimal alternative: just drop the
`network-online` lines and add a comment that connectivity is best-effort.

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
# After deploy: sudo systemctl start restic-check-local.service && \
#   journalctl -u restic-check-local.service -n 60 --no-pager
```

---

## P1-3 — `mac` USBGuard decision

**Issue:** `mac` is a portable laptop planned to travel, with no USB device
control and no recorded rationale.

**Fix option A (add minimal USBGuard, default-deny):** add to
`hosts/mac/default.nix` services block, populating allow rules from the live
machine (`usbguard generate-policy` on the Mac, then prune to needed devices):

```nix
  services.usbguard = {
    enable = true;
    rules = ''
      # Generated from `usbguard generate-policy` on mac; prune to essentials.
      # allow id <vendor>:<product>  # built-in webcam / Bluetooth / etc.
      reject
    '';
  };
```

Remember to persist `/var/lib/usbguard` (add to `hosts/mac/impermanence.nix`),
exactly as `main` does, or rule hashes reset each boot.

**Fix option B (document the omission)** — add to `hosts/mac/CLAUDE.md`
Gotchas:

```md
- **No USBGuard** — accepted while the host stays at home. Add a default-deny
  USBGuard policy (and persist `/var/lib/usbguard`) before the laptop travels,
  alongside the LUKS-keyfile revert.
```

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host mac
```

---

## P1-4 — Anonymous spec still mounts persistent identity directories

**Issue:** `anonymous.nix` `mkForce`s only `.files` (to drop machine-id) but
leaves the full `.directories` persist list (tailscale, bluetooth, NM profiles,
fprint) bind-mounted from `/persist`, undercutting the amnesic claim.

**Current** (`hosts/main/anonymous.nix`):

```nix
      environment.persistence."/persist".files = lib.mkForce [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
```

**Fix:** also force the directories list down to the minimum the spec needs.
Keep `/var/lib/nixos` (the uid/gid mapping the tmpfs-home comment depends on) and
brightness/rfkill UX state; drop network/identity state:

```nix
      environment.persistence."/persist" = {
        files = lib.mkForce [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];
        # Amnesic: do not mount persistent tailnet/Wi-Fi/Bluetooth/fprint
        # identity while running anonymously. Keep only what boot/UX needs.
        directories = lib.mkForce [
          "/var/lib/nixos"            # stable uid/gid for the tmpfs-home uid=1000 assumption
          "/var/lib/systemd/backlight"
          "/var/lib/systemd/rfkill"
        ];
      };
```

Caution: dropping `/var/log` from persistence in this spec is desirable
(amnesic) but confirm nothing in the spec asserts on it. Build and, ideally,
boot-test the specialisation.

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main      # builds the anonymous specialisation too
# Manual: reboot into the nixos-anonymous-* entry, then:
#   findmnt /var/lib/tailscale   # should NOT be a bind mount from /persist
#   mullvad status && mullvad lockdown-mode get
```

---

## P2-1 — Alert on silent `tailscale-bypass-routing` failure

**Issue:** the bypass script `exit 0`s when it cannot discover the tailscale
table, so `systemd-failure-notify` never fires even though tailnet traffic may
fall onto the Mullvad tunnel.

**Current** (`hosts/main/networking.nix`):

```nix
    if [ -z "''${tailscale_table:-}" ]; then
      echo "tailscale-bypass-routing: could not discover tailscale routing table" >&2
      exit 0
    fi
```

**Fix:** emit a textfile metric so the dashboard/alerts can see it, while still
not blocking boot:

```nix
    metric=/var/lib/node-exporter-textfiles/tailscale_bypass_routing.prom
    write_metric() {
      tmp="$metric.tmp"
      {
        echo "# HELP tailscale_bypass_routing_applied 1 if tailnet bypass rules were applied"
        echo "# TYPE tailscale_bypass_routing_applied gauge"
        echo "tailscale_bypass_routing_applied $1"
      } > "$tmp"
      mv "$tmp" "$metric"
    }

    if [ -z "''${tailscale_table:-}" ]; then
      echo "tailscale-bypass-routing: could not discover tailscale routing table" >&2
      write_metric 0
      exit 0
    fi
    # ... rule installation ...
    write_metric 1
```

Then add a dashboard panel/alert on `tailscale_bypass_routing_applied == 0`.

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
```

---

## P2-2 — Periodic full restic data check

**Issue:** `restic-check-local` only reads a 1 GB subset weekly; unread packs go
unverified for a long time on a single-copy backup.

**Current** (`hosts/main/backups.nix`):

```nix
        ExecStart = "${pkgs.restic}/bin/restic check --repository-file=${config.sops.secrets.restic_repository.path} --read-data-subset=1G";
```

**Fix:** either size the subset as a percentage that fully covers the repo over
N weeks, e.g. `--read-data-subset=10%` (full coverage in ~10 weeks), or add a
second monthly timer running `restic check --read-data`. Lowest-friction:

```nix
        ExecStart = "${pkgs.restic}/bin/restic check --repository-file=${config.sops.secrets.restic_repository.path} --read-data-subset=10%";
```

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host main
```

---

## P2-3 — Optional local btrbk snapshots on `mac`

**Issue:** `mac` rolls back `@root` but has no local snapshots/backups of
`@home`/`@persist`; accidental deletes mean a full reinstall.

**Fix (optional):** add a lightweight btrbk instance mirroring `main`'s
`backups.nix` pattern (the `/.btrfs-root` hidden mount + `btrbk.instances.local`
with `@home`/`@persist`, `snapshotOnly = true`). Cheap (CoW) and gives
point-in-time local recovery. Adapt the device label to `mac-root`.

**Validate:**

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh host mac
```

---

## P2-4 — Clarify node-exporter collector list

**Issue:** `enabledCollectors` reads like a complete set; it actually augments
the default-on collectors. `power_supply` still runs (battery panel works), but
this is easy to break by "tidying."

**Current** (`modules/nixos/profiles/observability/collectors.nix:460`):

```nix
          enabledCollectors = [
            "cpu"
            "filesystem"
            ...
            "thermal_zone"
          ];
```

**Fix:** add a clarifying comment (no functional change):

```nix
          # NOTE: this augments node_exporter's default-on collectors (which
          # still run, incl. power_supply used by the Battery dashboard panel).
          # Only thermal_zone here is default-off and needs explicit enabling.
          enabledCollectors = [ ... ];
```

**Validate:** `bash scripts/validate.sh flake-eval`

---

## P2-5 / P2-\* — Documentation-only runbook additions

- **P2-5 USBGuard new-stick procedure** → add to `hosts/main/CLAUDE.md` USB
  section: `usbguard list-devices` to read id/serial, add an
  `allow id … serial …` line, rebuild.
- These are `.md`-only; per repo policy doc edits are Gemini's lane, but the
  fix agent may add them inline with code changes if doing the code change too.

No build impact; `pre-commit run --all-files` for the markdown lint/format hooks.

---

## P3 — Future (no immediate code, capture as issues)

- **P3-1** Monthly automated restic restore canary + last-restore-test metric.
- **P3-2** Automated/escrowed age-key off-host backup to break the
  restic↔sops↔SSH-host-key cycle declaratively.
- **P3-3** Declarative `mac.travelMode` flag toggling LUKS keyfile vs
  passphrase/FIDO2, replacing the manual revert checklist.
- **P3-4** Add initrd SSH (or FIDO2) recovery to `mac` _before_ removing the
  keyfile for travel — otherwise a keyfile-less, TPM-less mac is unrecoverable
  remotely.
- **P3-5** Confirm coredump storage limits on `main` (`/var/lib/systemd/coredump`
  is persisted and unbounded; may contain secrets).
