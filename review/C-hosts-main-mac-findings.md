# Review C — Host configs `main` + `mac`

Deep correctness review of the `main` (NixOS workstation) and `mac` (NixOS on
2017 MacBook Air) host configurations. Scope: silent failures, fragile/incomplete
setups, gaps, and worthwhile future additions. Style/lint issues are excluded.

All `nix eval`/`nix build`/`statix`/`deadnix` already pass; everything below
evaluates fine but is wrong, fragile, or missing in practice.

Severity key: **P0** silent failure / broken · **P1** significant gap or
security weakness · **P2** optimization / robustness · **P3** future addition.

---

## Sops cross-reference — CLEAN

Verified every `sops.secrets.<name>` against `.sops.yaml` and the encrypted
files on disk:

- `main`: `user_password`, `observability_ingest_password`, `restic_password`,
  `restic_repository`, `b2_credentials`, `initrd_ssh_host_ed25519_key` — all
  present in `hosts/main/secrets/secrets.yaml`, which is matched by the
  `hosts/main/secrets/.*` rule (`*user` + `*main_host`). Good.
- `mac`: `user_password`, `root_password`, `observability_ingest_password`,
  `wpa_supplicant_wlp3s0_conf` present in `hosts/mac/secrets/secrets.yaml`;
  `luks_keyfile` lives in its own `hosts/mac/secrets/luks-keyfile.enc` (also
  matched by `hosts/mac/secrets/.*`). Good.

No dangling secret references and no orphaned secrets in either host file.
(`observability_ingest_password` is consumed by `observability-client.nix`,
not the host file — not an orphan.)

---

## P0 — Silent failures

### P0-1 · `mac` fail2ban ban database is wiped on every reboot

**File:** `hosts/mac/impermanence.nix:17-25` (absence) vs
`modules/nixos/profiles/security.nix:34` (fail2ban enabled) and
`hosts/mac/default.nix:153` (`openssh.enable = true`).

`security.nix` enables `fail2ban` fleet-wide and `mac` enables OpenSSH, so
fail2ban actively maintains a ban database at `/var/lib/fail2ban`. `mac` has an
ephemeral root (`rollbackRoot.enable = true`) but does **not** persist
`/var/lib/fail2ban`. Every reboot the ban list resets to empty — repeat
offenders get a clean slate and `bantime-increment`/`overalljails` escalation
state is lost. `main` correctly persists this path
(`hosts/main/impermanence.nix:33`); `mac` is an unintended asymmetry.

Impact is bounded (SSH is Tailscale-scoped, key-only), but this is a real
silent state loss that the persist-list audit is supposed to prevent.

**Fix:** add `"/var/lib/fail2ban"` to
`hosts/mac/impermanence.nix` `environment.persistence."/persist".directories`.

---

## P1 — Significant gaps / security

### P1-1 · Whonix KVM images are persisted but never backed up, and live on the rollback-exposed surface only by bind-mount

**File:** `hosts/main/impermanence.nix:43`, `hosts/main/backups.nix:34-61`.

`/var/lib/libvirt` is persisted (so the Whonix-Gateway/Workstation qcow2 images
survive the ephemeral-root rollback), but it is **not** in
`services.restic.backups.local.paths`. The host CLAUDE.md "Whonix KVM" section
treats these VMs as durable infrastructure (persistent libvirt domains,
"images live at /var/lib/libvirt/images/ … so they survive the rollback"), yet
disk loss destroys them with no B2 copy. Rebuilding a Whonix pair from scratch
(download, verify, import, re-pair Gateway/Workstation networking) is a
multi-hour manual job.

Either decision is defensible, but it should be explicit. If intentionally
out-of-backup (images are large and re-downloadable), document it in the
"Whonix KVM" / "Backups" sections the same way `mac`'s "No backups" note does.
If not, add the path (or at least the domain XML under
`/var/lib/libvirt/qemu/*.xml`) to the restic paths.

**Fix:** add `/var/lib/libvirt` (or a narrower domain-definitions subset) to
`services.restic.backups.local.paths`, or add an explicit "intentionally not
backed up" note. Note the backup⊆persist invariant
(`flake/checks.nix:119`) already passes for this path since it is persisted.

### P1-2 · `restic-check-local` orders on `network-online.target`, which `main` never reliably reaches

**File:** `hosts/main/backups.nix:98-101`, `hosts/main/networking.nix:126-127`.

`restic-check-local` does `after`/`wants` `network-online.target`, but `main`
force-disables both `NetworkManager-wait-online` and
`systemd-networkd-wait-online`. With no wait-online provider enabled,
`network-online.target` is reached effectively immediately at boot regardless of
real connectivity. For a _timer-triggered_ weekly check the machine is usually
already online, so this is low-impact — but the ordering is giving a false sense
of "waits for network" that it does not actually provide. The B2 reachability
this job needs is not guaranteed at the moment the target fires.

The restic backup job (`backups.local`, wired via `backup.nix`) has the same
latent issue; the module supplies its own ordering but the same wait-online gap
applies.

**Fix:** either drop the `network-online.target` dependency (it is a no-op here)
or, better, gate on actual Tailscale/B2 reachability. A pragmatic option is to
leave it but add a comment that `network-online` is a no-op on this host so a
future reader does not rely on it. For correctness, a small `ExecStartPre` that
polls the B2 endpoint with a bounded retry would make the dependency real.

### P1-3 · `mac` desktop has no equivalent to `main`'s USBGuard, and that gap is undocumented as a security decision

**File:** `hosts/mac/default.nix` (absence) vs `hosts/main/default.nix:471`.

`main` runs USBGuard with a default-deny policy. `mac` is a portable laptop that
"stays at home" today but is explicitly planned to travel (the LUKS-keyfile
revert checklist in `hosts/mac/CLAUDE.md` is all about travel). A traveling
laptop with no USB device control is the exact threat model USBGuard addresses
(BadUSB / juice-jacking at conferences/airports), yet there is no mention of the
omission. This is a deliberate-looking asymmetry with no recorded rationale.

**Fix:** either add a minimal USBGuard allowlist for `mac` (its built-in
keyboard/trackpad are PCI/SPI, not USB, so a default-deny policy is feasible),
or add a one-line "no USBGuard — accepted because <reason>" note to
`hosts/mac/CLAUDE.md` Gotchas so the decision is explicit and revisited before
travel.

### P1-4 · Anonymous spec drops Tailscale persistence implicitly via `mkForce`, leaving `/var/lib/tailscale` on the ephemeral root — but the _base_ persist list still references many tailnet-irrelevant paths

**File:** `hosts/main/anonymous.nix:34-37`.

`anonymous.nix` does `environment.persistence."/persist".files = lib.mkForce [...]`
to drop `/etc/machine-id` for a fresh transient ID. This `mkForce` only touches
`.files`, not `.directories`, so the full base `.directories` persist list (incl.
`/var/lib/tailscale`, `/var/lib/bluetooth`, `/etc/NetworkManager/system-connections`,
`/var/lib/fprint`) is still bind-mounted from `/persist` in the anonymous spec —
even though the spec disables Tailscale, Bluetooth, fprintd and randomizes MACs.
That means in anonymous mode the persistent tailnet node identity, saved Wi-Fi
profiles, and Bluetooth pairings are still mounted and readable, partially
undercutting the "amnesic, clean-slate" intent. The tmpfs `/home/user` hides
user-level artifacts but system-level identity state under `/persist` remains
exposed in-session.

This is a hardening gap, not a leak to the network, but it weakens the amnesic
claim documented in `hosts/main/CLAUDE.md` ("no logins, cookies, history, or
scan artifacts").

**Fix:** in `anonymous.nix`, also `mkForce` the `.directories` list down to the
minimum the spec actually needs (likely empty, or just
`/var/lib/systemd/backlight`/`rfkill`), so persistent network/identity state is
not mounted while running anonymously. Verify the spec still boots (Home Manager
relies on `/var/lib/nixos` for the uid mapping noted in the comment — keep that
one).

---

## P2 — Robustness / optimization

### P2-1 · `tailscale-bypass-routing` table discovery is best-effort and exits 0 on failure

**File:** `hosts/main/networking.nix:36-39`.

If table discovery fails after 5 attempts the script logs and `exit 0`s. That is
the right call for not blocking boot, but it means a silent failure mode: tailnet
traffic can fall back onto Mullvad's tunnel (breaking MagicDNS / tailnet
reachability) with no alerting. `systemd-failure-notify` won't fire because the
unit succeeds. Given the CLAUDE.md explicitly calls this "load-bearing" and
"fragile," a soft failure here is invisible.

**Fix:** emit a node-exporter textfile metric (e.g.
`tailscale_bypass_routing_applied 0/1`) on the failure path and add a dashboard
panel / alert, or write to the journal at a level `systemd-failure-notify`
watches. At minimum, leave a comment that failure is silent by design.

### P2-2 · `restic-check-local` only verifies 1 GB of pack data per run

**File:** `hosts/main/backups.nix:105` (`--read-data-subset=1G`).

A weekly 1 GB subset check is a reasonable cost/coverage tradeoff, but for a
single-copy B2 backup it can take a very long time to statistically cover the
whole repo, and bit-rot in unread packs goes undetected for a long time. Worth a
periodic (e.g. monthly) full `--read-data` check, or `--read-data-subset=N%`
sized so the repo is fully covered over a bounded window.

**Fix:** add a second, less-frequent timer running `restic check --read-data`,
or switch the subset to a percentage that guarantees full coverage over N weeks.

### P2-3 · `mac` has an ephemeral root but no snapshots and no backups → zero local recovery granularity

**File:** `hosts/mac/default.nix`, `hosts/mac/impermanence.nix`.

`mac` rolls `@root` back every boot but, unlike `main`, has neither btrbk local
snapshots of `@home`/`@persist` nor restic backups. The CLAUDE.md says recovery
is "fresh install + Syncthing re-pair," which is fine for synced data, but any
mac-local-only state in `/home` or `/persist` (e.g. an in-progress file not yet
synced, Bluetooth pairings, NM profiles) has no point-in-time recovery and no
off-host copy. Acceptable for a thin client, but the persisted-but-unsnapshotted
`/persist` paths are a quiet single point of failure.

**Fix:** optionally enable a lightweight local btrbk instance on `mac` (cheap;
snapshots are CoW) for `@home`/`@persist` so an accidental delete is recoverable
without a full reinstall. Or document explicitly that `/persist` on mac is
unprotected.

### P2-4 · `main` battery/thermal node-exporter coverage is incomplete relative to the dashboard

**File:** `modules/nixos/profiles/observability/collectors.nix:460-469`,
`hosts/main/dashboard.nix:80-96`.

The dashboard's "Battery %" panel queries `node_power_supply_capacity` and
"Thermal Zones" queries `node_thermal_zone_temp`. `thermal_zone` is explicitly
enabled (good — it is default-off). `power_supply` is a default-on collector so
the battery panel does work, but the explicit `enabledCollectors` list reads as
if it were the _complete_ set, which invites someone to later "tidy" it and
accidentally believe power_supply must be added/removed. There is also no
`hwmon` collector, so per-sensor fan/voltage data is unavailable if ever wanted.

**Fix:** add a comment that `enabledCollectors` augments the default-on set
(power_supply, etc. still run), or add `power_supply` explicitly for clarity.
No functional bug — clarity/robustness only.

### P2-5 · `usbguard` allowlist pins two specific backup/installer USB sticks by serial — fragile operationally

**File:** `hosts/main/default.nix:502-508`.

The SanDisk and Toshiba sticks are allowlisted by serial. If either stick dies
or is replaced, backups/installs silently can't mount the new stick until the
config is edited and rebuilt. This is correct from a security standpoint but is
an operational footgun worth a runbook note ("to authorize a new stick: get its
id/serial via `usbguard list-devices`, add an `allow id … serial …` line,
rebuild").

**Fix:** add the procedure to `hosts/main/CLAUDE.md` (USB device control
section). No code change required.

---

## P3 — Future additions

### P3-1 · No automated restore test for the restic/B2 backup

There is an excellent disaster-recovery runbook in `hosts/main/CLAUDE.md`, but
nothing verifies it works. A periodic (e.g. monthly) `restic restore` of a
canary path into a tmpdir, asserting the file round-trips, would catch a
silently-broken backup before you need it. Pair with a node-exporter metric so
the dashboard shows last-successful-restore-test timestamp.

### P3-2 · Age key backup has a documented circular dependency but no automated off-host escrow

`hosts/main/CLAUDE.md` documents that the age key must live in an external
password manager to break the restic↔sops↔SSH-host-key cycle. This is correct
but entirely manual. Consider a sops-encrypted-to-a-paper/HSM escrow step in the
runbook, or at least a periodic reminder/check that the offline copy exists.

### P3-3 · `mac` LUKS keyfile-in-initrd is a known at-rest weakness with a manual revert checklist — no enforcement

`hosts/mac/default.nix:92-106` bakes a LUKS keyfile into the (unencrypted-ESP)
initrd "while the host stays at home." The revert-before-travel steps are
documented but nothing enforces them. A FIDO2 enrollment (the documented target)
or a build-time flag (`mac.travelMode`) that flips between keyfile and
passphrase/FIDO2 would make the security posture declarative instead of relying
on remembering a checklist.

### P3-4 · No `boot.initrd` SSH recovery path on `mac` (only `main` has one)

`main` has initrd SSH (port 2222) for remote LUKS unlock. `mac` relies on the
baked keyfile, so today there is no need — but the moment the keyfile block is
removed for travel, there is no remote-unlock fallback at all. If `mac` ever
travels, add an initrd SSH unit (or FIDO2) before removing the keyfile, else a
TPM-less, keyfile-less mac that fails to take the passphrase is unrecoverable
remotely.

### P3-5 · Consider persisting `/var/lib/systemd/coredump` policy review on `main`

`coredump` is persisted (good for forensics) but with full desktop + browsers +
proprietary blobs, coredumps can contain secrets and grow `/persist` unbounded.
Worth confirming `coredumpctl`/`storage` limits are set, or excluding it from B2
(it is currently not in the restic paths, so only local — fine, but the local
growth is unbounded).

---

## Symmetry summary (`main` vs `mac`)

| Concern                       | main | mac                              | Note               |
| ----------------------------- | ---- | -------------------------------- | ------------------ |
| Ephemeral root + rollback     | yes  | yes                              | symmetric          |
| fail2ban DB persisted         | yes  | **no (P0-1)**                    | fix                |
| USBGuard                      | yes  | **no (P1-3)**                    | decide             |
| Restic/B2 backup              | yes  | none (documented)                | ok-ish (P2-3)      |
| Local btrbk snapshots         | yes  | none                             | P2-3               |
| initrd SSH recovery           | yes  | none (keyfile instead)           | P3-4               |
| Secure Boot (Lanzaboote)      | yes  | n/a (no T2)                      | hardware           |
| LUKS unlock                   | TPM2 | keyfile-in-initrd (at-rest weak) | P3-3               |
| Tailscale-scoped SSH firewall | yes  | yes                              | symmetric, correct |

Both hosts correctly scope SSH to `tailscale0` only (`openFirewall = false` on
sshd, interface-scoped `allowedTCPPorts`), and `security.nix` would warn if a
global 22/443 were opened. Firewall intent is sound on both.
