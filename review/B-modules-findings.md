# Module Review B — `modules/nixos/` Findings

Domain: shared NixOS modules and profiles. All findings evaluate fine; they are
behavioral, security, or robustness issues that `nix eval`/`statix`/`deadnix`
do not catch.

Severity legend: **P0** broken / silent failure · **P1** significant gap or
security · **P2** optimization / robustness · **P3** future addition.

---

## P0 — Silent failures / broken behavior

### P0-1 `services.hardened` applies the entire baseline at `mkDefault` — most keys are silently no-ops

`modules/nixos/services/hardened.nix:106-114`

The baseline sandbox options are merged as `lib.mapAttrs (_: lib.mkDefault) passiveBase`.
The comment says "apply at mkDefault so nixpkgs modules win." That is exactly the
problem for _hardening_: any service whose upstream nixpkgs module already sets one
of these keys (e.g. nginx's module sets `ProtectSystem`, `ProtectHome`,
`NoNewPrivileges`, etc.; vaultwarden's module sets several) will keep the upstream
value and **silently drop the hardened baseline value** for that key. The operator
believes they applied a strict baseline, but for already-set keys the module does
nothing. There is no warning or assertion that flags "baseline key X was overridden
by a higher-priority definition." For `nginx`/`vaultwarden` on homeserver-gcp this
means the advertised baseline (`SystemCallFilter = ["@system-service"]`,
`MemoryDenyWriteExecute`, `RestrictAddressFamilies`, etc.) may not be in force at
all for any key the upstream unit already defines, and you cannot tell from the Nix
config alone.
Fix: either raise the passive baseline to normal priority (so it overrides nixpkgs
unless the host explicitly opts out via `relaxBase`), or emit a build-time
assertion/warning when a baseline key is shadowed. The current `mkDefault` semantics
contradict the module's stated security purpose. At minimum document that the
baseline is "best effort, nixpkgs wins" and add a `verify`/test that dumps the final
`systemd-analyze security <unit>` for the hardened units.

### P0-2 Alertmanager routes every alert to a `null` receiver — alerts fire into the void

`modules/nixos/profiles/observability/alerts.nix:127-142`

All nine alert rules (SystemdUnitFailed, ResticBackupStale, VulnixCveFound, etc.)
are routed to `receiver = "null"` with a single `{ name = "null"; }` receiver and no
notification integration. The comment acknowledges this ("Wire a real receiver…").
Net effect: a failed backup, a stale integrity check, or a CVE finding produces an
alert that is visible only if someone opens Grafana/Alertmanager and looks. There is
no email, no ntfy/Pushover, no push. Combined with P1-1 (failure-notify is
desktop-only), the homeserver-gcp host has **no out-of-band path** to tell the
operator that anything broke. This is the single biggest operational gap in the
stack: the whole alerting pipeline is plumbed but terminates in `/dev/null`.
Fix: add a real receiver (the repo already has sops; an SMTP or ntfy webhook
receiver is a few lines) and make the receiver configurable via a
`profiles.observability.alerting` option block with a sops-backed secret.

### P0-3 `metricsRemoteWriteAuth` is applied even when there is no remote write URL, and basic-auth password is sent without TLS verification config

`modules/nixos/profiles/observability/collectors.nix:17-22,485-500`

`metricsRemoteWriteAuth` is computed purely from `shouldUseIngestAuth`
(`ingestAuth.username != null && ingestAuth.passwordFile != null`) and is spliced
into the remote-write block whenever `remoteWriteURL != null`. That part is fine.
The latent bug: when `remoteWriteURL == null` but `mimir.enable` is true (the
homeserver-gcp self-monitoring case), the code path at line 496 produces a
remote-write block to local Mimir **without** auth — correct — but if a host ever
sets _both_ `ingestAuth.*` and leaves `remoteWriteURL = null` while `mimir.enable`
is false, metrics are silently dropped (no remote write target at all, no warning).
There is no assertion that "metrics.enable with neither remoteWriteURL nor
mimir.enable means metrics go nowhere." A host that enables metrics collection but
forgets the destination scrapes locally into a 24h-retention Prometheus and never
ships anything — a silent data-loss config that evaluates fine.
Fix: add an assertion: `metrics.enable → (remoteWriteURL != null || mimir.enable)`,
or a warning when neither is set.

---

## P1 — Significant gaps / security

### P1-1 `systemd-failure-notify` is desktop-only and fails silently on headless hosts

`modules/nixos/services/systemd-failure-notify.nix:18-22`

The notify script only does `notify-send` when `$DISPLAY`/`$WAYLAND_DISPLAY` is set;
otherwise it merely writes a journal line via `systemd-cat`. On homeserver-gcp (no
display) the `OnFailure=` handler runs but produces only another journal entry —
i.e. it notifies nobody. On `main`/`mac` the `notify-failure@.service` is a _system_
service with no user-session environment, so `$WAYLAND_DISPLAY` is essentially never
set there either; the desktop toast path is effectively dead on all three hosts. The
unit is wired to `btrbk-local`, `restic-*`, `thermald`, etc. on main, giving a false
sense that failures will surface. End-to-end this never reaches a human.
Fix: drop the dead desktop branch or run it as a user service with the session
environment; for servers route `OnFailure` to the same notification channel
recommended in P0-2. There is no concept of an unreachable-target fallback — if the
channel is down the failure is lost.

### P1-2 `machine-dev.nix` broad passwordless sudo is import-gated only — no host-class guard

`modules/nixos/profiles/machine-dev.nix:1-9`

`security.sudo.wheelNeedsPassword = false` plus `services.openssh.openFirewall = true`
plus trusting `user` in the Nix daemon are all unconditional. The only thing keeping
this off `main` is "don't import this file" (a comment). It is imported transitively
by `microvm-guest.nix`. There is no assertion tying it to a `profiles.machineClass`
or a `profiles.ci`/disposable flag, so a future host that imports `microvm-guest`
inherits root-equivalent SSH + trusted-user Nix substitution without any explicit
opt-in. Given the repo's own security model (main keeps `wheelNeedsPassword = true`),
this is the easiest profile to leak dangerous settings.
Fix: gate the body behind an explicit `lib.mkIf config.profiles.machineDev.enable`
option (default false) or add an assertion that the host has declared itself
disposable. Make the danger declarative rather than load-bearing on an import-site
comment.

### P1-3 `services.hardened` has no `RestrictAddressFamilies` for `AF_NETLINK`/`AF_PACKET` consideration, and several common hardening sysctls are missing from `security.nix`

`modules/nixos/profiles/security.nix:60-69`

The kernel sysctl block covers the classic redirect/source-route/bpf set but omits
several widely-recommended hardening sysctls that cost nothing here:

- `kernel.kptr_restrict = 2` (hide kernel pointers)
- `kernel.dmesg_restrict = 1`
- `kernel.yama.ptrace_scope = 1` (ptrace hardening; high value on a multi-process
  desktop)
- `net.ipv4.conf.all.rp_filter` / reverse-path (note: main/mac/gcp set
  `checkReversePath = "loose"` deliberately, so this one must stay host-overridable)
- `kernel.unprivileged_userns_clone = 0` is **not** set, yet `RestrictNamespaces` is
  applied per-service — inconsistent posture (userns is left open system-wide).
- `net.core.bpf_jit_harden = 2`
- `kernel.kexec_load_disabled = 1`
- `kernel.perf_event_paranoid = 3` (note thermald needs perf; that's per-service)
  None of these are present. `boot.kernel.sysctl` here is the natural home for them.
  Also missing: `boot.blacklistedKernelModules` for unused network protocols
  (`dccp`, `sctp`, `rds`, `tipc`) and rare filesystems — standard CIS/Lynis items that
  would raise the `lynis_hardening_index` the alerts already track.
  Fix: extend the sysctl set above with the host-safe subset; keep userns/ptrace
  choices explicit and documented because they can break sandboxes (Chromium,
  bubblewrap) — guard or test before enabling `unprivileged_userns_clone = 0`.

### P1-4 `nix-trusted-users.nix` warns on broad trust but does not block it

`modules/nixos/profiles/nix-trusted-users.nix:34-36`

`broadTrustedUsers` (entries equal to `*` or starting with `@group`) only produces a
`warnings` entry, not an assertion. A trusted user can instruct the daemon to
substitute arbitrary store paths and set `system-features`, which is effectively
root. Given the repo treats this seriously elsewhere, demoting `*`/`@wheel` to a
mere warning means a future change adding `@wheel` would build cleanly. The
`trustedUserViolations` assertion only checks the _set_ matches
`extraTrustedUsers`; it does not reject broad patterns inside that set.
Fix: promote `broadTrustedUsers != []` to an assertion (or make it configurable with
a default-deny), so granting fleet-wide group trust requires an explicit override.

### P1-5 `impermanence-base.nix` old-root GC deletes by mtime but the rollback service has no failure notification and runs in initrd where journald-only logging is invisible

`modules/nixos/profiles/impermanence-base.nix:42-77`

`rollback-root` is `set -euo pipefail` and is `before = ["sysroot.mount"]`. If
`@root-blank` is missing or the btrfs subvolume ops fail, the boot stalls in initrd
with no notification path and no `OnFailure`. That is somewhat intended (fail-safe),
but the recursive `delete_subvolume_recursively` parses `btrfs subvolume list -o`
with `cut -f 9 -d ' '`, which is fragile: btrfs list output columns are not
guaranteed single-space-delimited and the path column position can shift across
btrfs-progs versions. A parsing regression would either delete the wrong subvolume
or silently delete nothing (old_roots growth). This is destructive code with no
test.
Fix: use `btrfs subvolume list -o --sort=path` with explicit `awk '{print $NF}'`
(path is the last field) instead of fixed `-f 9`, and add a VM test that boots,
populates `old_roots`, and asserts the rollback + 30-day prune behavior.

### P1-6 Grafana provisioning marks dashboards `editable = true; disableDeletion = false` — provisioned-from-store dashboards can be edited and the edits silently lost on redeploy

`modules/nixos/profiles/observability/default.nix:124-129`

Dashboards are file-provisioned from `/etc/grafana-dashboards` (immutable store
content) but with `editable = true` and `disableDeletion = false`. A user editing a
provisioned dashboard in the UI will have changes overwritten on the next reload/
redeploy with no warning — a classic "my dashboard changes vanished" footgun.
Fix: set `editable = false; disableDeletion = true;` for file-provisioned
dashboards (they are code), or make it an option.

---

## P2 — Optimizations / robustness

### P2-1 `base.nix` `exportSystemMetadata` activation script writes to a directory it does not guarantee exists in time and uses a tmpfile race-free move, but the `.prom` lives outside persistence

`modules/nixos/profiles/base.nix:16-34`

The metric `nixos_system_activated_at_seconds` is written under
`/var/lib/node-exporter-textfiles`. On impermanence hosts this dir is not in the
persistence list (correct — it's regenerated), and the activation script `install
-d` creates it. Fine. But there is no coupling between this activation script and the
node-exporter `textfile` collector directory flag — they share a hardcoded path
string in two files (`base.nix` and `collectors.nix:470`). If one changes, metrics
silently stop. Consider a single shared option/let-binding for the textfile dir.

### P2-2 `observability/default.nix` Grafana option lacks an assertion that `grafana.enable` implies a usable admin credential

`modules/nixos/profiles/observability/default.nix:71-87`

`adminPasswordFile` and `secretKeyFile` both default to `null`. If a host enables
Grafana but forgets the password file, Grafana boots with the built-in default
`admin/admin` and an ephemeral secret key (sessions invalidated on restart). No
assertion catches this. homeserver-gcp sets both, but the module permits the unsafe
combination silently.
Fix: assert `grafana.enable → (adminPasswordFile != null && secretKeyFile != null)`,
or at least warn.

### P2-3 `backup.nix` does not set `passwordFile`/`repositoryFile` and relies entirely on host wiring; no assertion that the named job is fully configured

`modules/nixos/profiles/backup.nix:21-31`

The profile only contributes `initialize`, `timerConfig`, `pruneOpts` to
`services.restic.backups.${backupName}`. If a host sets `hostMeta.backup` but never
defines the matching `restic.backups.<name>.paths`/`repositoryFile` (e.g. a typo in
the name vs. the registry `backup.name`), restic would back up nothing or fail at
runtime. The `hasResticBackup` registry invariant checks `repository`/
`repositoryFile` presence, which mitigates the repo case, but **does not check
`paths != []`** — an empty-paths job initializes a repo and backs up nothing, while
`restic_last_backup_timestamp_seconds` is still stamped by `ExecStartPost`, so the
`ResticBackupStale` alert stays green. That is a silent "successful empty backup."
Fix: add an invariant that the configured restic job has non-empty `paths`, and gate
the metrics `ExecStartPost` on actual snapshot success (restic exit code already
gates it, but empty paths is a "success").

### P2-4 `backup.nix` verification (`restic check --read-data-subset=1G`) never tests restore

host `backups.nix` (main/gcp) + `alerts.nix`

`restic check --read-data-subset=1G` verifies repository structure and re-reads 1 GB
of pack data, but never performs an actual `restic restore` to a scratch dir and
diffs. The dashboards/alerts track _check age_, not _restore success_. A repo can
pass `check` yet have an un-restorable snapshot due to environment/permission issues
at restore time. CLAUDE.md's recovery runbook is manual-only.
Fix (P3-adjacent): add a periodic restore-canary unit that restores a small known
path to a tmpdir, verifies a sentinel file, and exports a
`restic_last_restore_success_timestamp_seconds` metric with a matching alert.

### P2-5 `desktop.nix` enables `xdg.portal.config.common.default = "*"` which is deprecated/ambiguous portal routing

`modules/nixos/profiles/desktop.nix:55`

`default = "*"` tells xdg-desktop-portal to try every available portal backend for
every interface. With both the hyprland and gtk portals installed this can route
e.g. the FileChooser to the wrong backend non-deterministically. Hyprland docs
recommend explicit per-interface defaults (hyprland for Screenshot/ScreenCast, gtk
for FileChooser). Works "now" but is the classic source of broken screenshare/file
dialogs after a portal update.
Fix: set explicit `config.common.default = ["gtk"]` plus
`config.hyprland.default = ["hyprland" "gtk"]` or per-interface mappings.

### P2-6 `microvm-guest.nix` imports `machine-dev.nix` (broad sudo) unconditionally for every guest

`modules/nixos/profiles/microvm-guest.nix:5-9`

Any microvm built on this profile gets passwordless sudo + open SSH firewall +
trusted `user`. For a disposable guest that may be acceptable, but it is silent and
unconditional; combined with P1-2 it means "microvm" == "root-equivalent SSH" by
default. Make the dev posture an explicit opt-in even for guests.

---

## P3 — Future additions

### P3-1 No `boot.loader.timeout`/console hardening parity across profiles

Hardening like `kernel.kptr_restrict`, `lockKernelModules`, AppArmor, and
`security.protectKernelImage` (the nixpkgs hardening toggles) are not centralized.
`security.nix` is the right home for a `security.lockKernelModules`,
`security.protectKernelImage`, and `security.allowUserNamespaces` decision matrix
(documented per host because they break VMs/containers). Add as opt-in options.

### P3-2 Centralize the `node-exporter-textfiles` path and the LGTM localhost ports

Hardcoded `127.0.0.1:9009/3100/3200/4317/4318/14317/14318` and the textfile dir
appear across `default.nix`, `backends.nix`, `collectors.nix`, `base.nix`. A shared
`lib`/options module would prevent drift (P2-1) and make a second collector instance
possible.

### P3-3 `observability` profile has no assertion coupling backends to Grafana datasources

`default.nix` always provisions Mimir/Loki/Tempo datasources (uid mimir/loki/tempo)
even when `loki.enable`/`tempo.enable`/`mimir.enable` are false. On a host that
enables Grafana for remote datasources this is fine, but on a host enabling Grafana
with only some backends the datasources point at dead localhost ports and panels
error. Add an assertion or make datasource provisioning track backend enablement.

### P3-4 `systemd-failure-notify` could attach to all `enabled` services automatically

Currently each host hand-maintains a `services = [ … ]` list (main lists 5, mac
lists 2). Drift is guaranteed. A `failOnAll`/glob option, or wiring it to the same
journald `PRIORITY=3` audit stream already shipped to Loki, would be more robust than
the manual list.

### P3-5 Add a `systemd-analyze security` profile test for `services.hardened`

Directly addresses P0-1: a VM test that builds homeserver-gcp and asserts the exposure
level of nginx/vaultwarden units is below a threshold would catch the silent-noop
problem and any future regression where a baseline key gets shadowed.
