# Review D — homeserver-gcp + installer

Domain: `hosts/homeserver-gcp/*`, `hosts/installer/*`, and the shared
observability / security / backup profiles they consume. All findings below
evaluate and build cleanly; they are wrong (or risky) _in practice_.

Severity legend: **P0** broken / silent failure · **P1** significant
gap/security · **P2** optimization · **P3** future addition.

---

## P0 — Silent failures and broken behavior

### P0-1 — GCP firewall has no ingress restriction; relies on the `default` network's auto-allow rules

`infra/main.tf:9-21` only creates **one** firewall rule: allow UDP/41641
(Tailscale) from `0.0.0.0/0`. The VM is attached to `network = "default"`
(`main.tf:72`) with an `access_config {}` external IP (`main.tf:73`). The GCP
`default` VPC ships with auto-created rules `default-allow-ssh` (TCP/22 from
`0.0.0.0/0`), `default-allow-rdp` (TCP/3389), and `default-allow-icmp` — all
from anywhere. Nothing in this repo deletes or overrides them.

Consequences:

- TCP/22 is reachable from the public internet at the GCE NAT IP, completely
  bypassing the "tailnet-only SSH" claim in `hosts/homeserver-gcp/CLAUDE.md`.
  The host firewall (`default.nix:57-61`) only scopes ports on `tailscale0`,
  but nginx/sshd still bind `0.0.0.0`; the host nftables default-deny on other
  interfaces is what actually protects you — _if_ it is in effect. The GCP
  edge firewall, however, is wide open, so you are relying entirely on the
  in-guest firewall. Defense-in-depth is gone, and any in-guest firewall
  regression instantly exposes SSH to the internet.
- There is **no** GCP rule permitting inbound 80/443, yet the design intends
  HTTPS only over Tailscale anyway — so 443 from the internet is dropped by
  the in-guest firewall (good), but this is accidental, not declared.

Fix direction: add an explicit `google_compute_firewall` deny posture. Either
(a) move the VM to a dedicated VPC/subnet with no default-allow rules and add a
single rule permitting only UDP/41641, or (b) keep `default` but add a
high-priority `deny`-everything-ingress rule plus the Tailscale allow, and
remove the project's `default-allow-ssh`/`default-allow-rdp` rules in Terraform.
At minimum, do not depend on the in-guest firewall as the sole control on an
internet-facing NAT IP.

### P0-2 — Alertmanager is wired to a `null` receiver: no alert ever leaves the box

`modules/nixos/profiles/observability/alerts.nix:127-142` defines the
Alertmanager route with `receiver = "null"` and a single no-op receiver. Every
alert in the rules file (SystemdUnitFailed, ResticBackupStale, VulnixCveFound,
BlackboxProbeFailed, etc.) fires into a black hole. The alerting _looks_
complete — rules are provisioned, thresholds are sensible — but **nobody is
ever notified**. On an unattended internet-facing VM this is the single most
impactful operational gap: a failed backup, a stale CVE scan, or a down
Vaultwarden will sit silent until you happen to open Grafana.

Fix direction: wire a real receiver (the repo already hints at this in the
comment). Cheapest robust option for a personal setup: an SMTP receiver to the
operator email, or a webhook to a push service (ntfy/Pushover/Telegram bot).
Secret (SMTP creds / webhook token) via sops, injected through
`mimir.configuration.alertmanager` or by templating the alertmanager.yaml.

### P0-3 — Grafana is provisioned with no contact point / notification policy either

`modules/nixos/profiles/observability/default.nix:89-132` provisions
datasources and the dashboard provider, but **no** `contactPoints`,
`policies`, or `alerting` provisioning. Combined with P0-2, there is no
notification path through _either_ Mimir's Alertmanager _or_ Grafana unified
alerting. The "Backup Health" / "CVE Scan" / "Security Audit" dashboards
(`dashboards.nix`) are purely visual and require a human to look.

Fix direction: provision Grafana contact points + a notification policy
declaratively (`services.grafana.provision.alerting.*`), or commit to the
Mimir Alertmanager path in P0-2. Pick one; don't leave both null.

### P0-4 — `restic-backups-b2` success metric is written even when the backup _fails_

`backups.nix:4-12`: the `restic_last_backup_timestamp_seconds` metric is
emitted from `ExecStartPost`. systemd runs `ExecStartPost` for the unit's
post-start phase; with `Type=oneshot` (the NixOS restic module default),
`ExecStartPost` runs after the main `ExecStart`, but **ExecStartPost runs even
if you do not gate it on success unless the main process failed hard**. More
importantly, the NixOS restic module composes the backup as multiple
`ExecStart=` lines (backup + forget/prune); a _prune_ failure or a _partial_
backup can still leave `ExecStartPost` running and stamp a fresh "successful
backup" timestamp. The `ResticBackupStale` alert (alerts.nix:53-61) keys off
exactly this timestamp, so a silently-degrading backup will never trip the
staleness alarm. The status page badge (`status-page.nix:380`) inherits the
same false-green.

Fix direction: gate the metric on actual success. Either move the stamp into a
separate `OnSuccess=`/`ExecStartPost=` that checks `$SERVICE_RESULT` /
`$EXIT_STATUS`, or better, drive the metric from `restic snapshots` (query the
repo for the latest snapshot timestamp) so the gauge reflects the repository,
not the unit's exit path. Same applies to `restic-check-b2` (backups.nix:22-30)
— though there `Type=oneshot` + single ExecStart makes a failure abort before
ExecStartPost, so it is lower risk.

### P0-5 — Restic backup omits AdGuard's _real_ state path and other recovery-critical data

`backups.nix:46-50` backs up `/var/lib/vaultwarden`, `/var/lib/grafana`,
`/var/lib/private/AdGuardHome`. Gaps that break a clean-machine restore:

- **Loki / Mimir / Tempo data is not backed up.** That is arguably acceptable
  (telemetry is regenerable) — but the _Mimir alert rules and Alertmanager
  config_ live under `/var/lib/mimir/rules` and `/var/lib/mimir/alertmanager`,
  re-provisioned from the Nix store on deploy, so OK. Document the decision.
- **Grafana dashboards** are file-provisioned (`/etc/grafana-dashboards`) from
  Nix, but Grafana's SQLite (`/var/lib/grafana/grafana.db`) holds _user
  accounts created via auth-proxy auto_sign_up, alert state, annotations,
  and any manually starred/edited dashboards_. `/var/lib/grafana` is included,
  good — but verify the restic run isn't snapshotting a live SQLite file
  mid-write (no `.backup`/WAL-checkpoint hook). A torn DB restore is a silent
  data-loss risk.
- **AdGuard `mutableSettings = true`** (`adguard.nix:4`) means the _entire_
  effective config (admin user, upstreams, blocklists, per-client rules) lives
  only in `/var/lib/private/AdGuardHome` on disk and is hand-edited via the web
  UI. It _is_ in the restic set — good — but there is no verification that the
  systemd `DynamicUser` path `/var/lib/private/AdGuardHome` is actually what
  restic reads (it is a symlink target; confirm restic follows it, see P1-7).

Fix direction: add a Grafana SQLite consistency step (sqlite `.backup` to a
staging file that restic picks up, or stop-the-world is overkill — use
`VACUUM INTO`). Document explicitly what is and isn't recoverable.

### P0-6 — `restic check --read-data-subset=1G` re-downloads 1 GB from B2 weekly with no egress/cost guard, and only ever verifies the same first slice

`backups.nix:21`: `--read-data-subset=1G` reads a _fixed_ 1 GB. Per restic
semantics, `--read-data-subset=1G` selects a deterministic subset by pack ID
hash, so over time it does rotate, but a fixed byte budget on a growing repo
means coverage shrinks. More operationally: B2 download egress is billed; a
weekly 1 GB read is fine, but there is no alert if the _check itself_ never
runs successfully other than `ResticCheckStale` (8-day threshold). Acceptable,
but flagged because the metric write (backups.nix:22-30) again only reflects
"the unit reached ExecStartPost," not "check found no errors" — `restic check`
exits non-zero on corruption, which _does_ abort before ExecStartPost, so this
one is genuinely gated. Lower priority than P0-4.

---

## P1 — Security and significant operational gaps

### P1-1 — No security response headers on an internet-adjacent reverse proxy

`nginx.nix` sets `recommendedTlsSettings = true` and `recommendedProxySettings
= true` but adds **no** HSTS, CSP, X-Frame-Options, X-Content-Type-Options,
Referrer-Policy, or Permissions-Policy. NixOS `recommendedTlsSettings` does
_not_ add HSTS. For a host serving Vaultwarden (a password manager) this is a
real gap:

- No `Strict-Transport-Security` → first-request downgrade / strip risk for
  any client that reaches the NAT IP name.
- No `X-Frame-Options`/`frame-ancestors` → Vaultwarden vault UI can be framed.
- The homepage SSE/JSON endpoints set per-location `add_header`, but because
  any single `add_header` in a nested location **drops all inherited
  add_headers**, even if you add server-level security headers later they will
  silently vanish on `/home/*`, `/home/status.json`, etc.

Fix direction: add a shared `extraConfig` of `add_header ... always;` at the
`virtualHosts.<fqdn>.extraConfig` level (server scope), and re-assert the full
header set inside every location that already calls `add_header` (the
Cache-Control ones) so they are not silently dropped. HSTS
`max-age=63072000; includeSubDomains`.

### P1-2 — Vaultwarden admin panel exposure is not explicitly disabled

`default.nix:167-175` configures Vaultwarden with `SIGNUPS_ALLOWED = false`
(good) but does **not** set `ADMIN_TOKEN` to a disabled/empty state nor
explicitly confirm the `/admin` panel is off. With no `ADMIN_TOKEN`, recent
Vaultwarden versions disable `/admin` by default — but `nginx.nix:52` proxies
`location "/" → 8222` with no carve-out, so `/admin` is reachable over the
tailnet. Relying on the upstream default to keep `/admin` closed is fragile.

Fix direction: either set `ADMIN_TOKEN` from a sops secret (argon2 hash) for
intentional admin access, or add an nginx `location = /admin { return 404; }`
and document that admin is disabled. Make the posture explicit.

### P1-3 — `/obs/*` ingest endpoints are reachable over the tailnet protected only by a single shared htpasswd, and `recommendedProxySettings` forwards client headers

`nginx.nix:142-159`: the three ingest push endpoints (Loki, Mimir, OTLP) are
behind `basicAuthFile` only. Any tailnet device (the ACL allows TCP/443 from
`workstation` tag, `lib/hosts.nix:213-218`) can push arbitrary logs/metrics/
traces if it has the shared credential. That is the intended design for a
single operator, but: (a) there is no rate limiting (a misbehaving Alloy could
fill the disk — Loki retention is 30 d but ingestion is unbounded), and (b) the
basic-auth credential is the _same_ `observability_ingest_htpasswd` for all
three signals, so compromise of one client leaks all ingest. Note also the
catch-all `location "/obs/" { return 404; }` precedes the exact-match push
locations; confirm the `= /obs/...` exact matches win over the prefix (they do
in nginx precedence — exact `=` beats prefix — so this is correct, but it is
subtle and worth a comment).

Fix direction: add `limit_req`/`client_max_body_size` on the ingest locations;
consider per-signal credentials. Document the precedence reliance.

### P1-4 — `mutableSettings = true` for AdGuard means config drift is invisible and not reproducible

`adguard.nix:4`. The declarative `settings` block only pins DNS upstreams and
bind hosts; the admin password, blocklists, per-client config, and query-log
settings are all set _imperatively_ via the setup wizard
(`CLAUDE.md` first-deploy step 7) and persist only on disk. Consequences:

- No blocklists are declared. Out of the box AdGuard ships with one default
  list; the review brief asks "are block lists comprehensive" — **the answer
  is no, they are whatever was clicked in the wizard, and not in git**.
- On a clean restore from snapshot-only (not restic), AdGuard comes back with
  the _baked_ defaults, not the operator's curated lists.
- The admin password is not in sops; it's a wizard artifact on disk.

Fix direction: flip to `mutableSettings = false` and declare
`settings.filters` (blocklists), `settings.users` (admin with a sops-sourced
bcrypt hash via a sops template), and `settings.dns.*` fully. This makes the
DNS posture reproducible and reviewable. If you want to keep web-UI edits, at
least declare the blocklists so they survive a baked-image rebuild.

### P1-5 — AdGuard upstream uses DoH to 1.1.1.1 / 8.8.8.8 but `bootstrap_dns` and the _first DNS query path_ leak in plaintext, and there is no upstream fallback strategy

`adguard.nix:11-18`: upstreams are DoH (good), bootstrap is plaintext
9.9.9.9/8.8.8.8 (expected, only used to resolve the DoH hostnames — but 1.1.1.1
and 8.8.8.8 are IP-literals so bootstrap is barely used). No DoT fallback, no
`upstream_mode`, no EDNS client-subnet disable. Minor, but: both upstreams are
US hyperscalers; for a privacy-oriented AdGuard the choice of _only_ Cloudflare

- Google is worth reconsidering (e.g., add Quad9 DoH, set
  `upstream_mode: parallel` or `load_balance`).

Fix direction: declarative upstreams (ties into P1-4), add Quad9, set an
explicit `upstream_mode`. Low security severity, more of a design choice.

### P1-6 — `security.sudo.wheelNeedsPassword = false` plus internet-reachable SSH (P0-1) = root-equivalent internet exposure

`default.nix:37`. The comment correctly notes SSH access is root-equivalent.
This is acceptable _only if_ SSH is truly tailnet-only. Given P0-1 (GCP edge
firewall does not block 22), the in-guest nftables rule is the _only_ thing
between the internet and passwordless root. fail2ban (security.nix:34-43) is
SSH-key-only (PasswordAuthentication=false), so brute force is moot, but key
exposure or an sshd CVE becomes root with no second factor.

Fix direction: fix P0-1 (edge firewall). Optionally keep `wheelNeedsPassword`
behavior but require a sudo password for the deploy user is impractical with
deploy-rs; the real mitigation is the network boundary.

### P1-7 — restic backs up the systemd `DynamicUser` private path directly; ownership/symlink semantics are fragile

`backups.nix:49` lists `/var/lib/private/AdGuardHome`. Under systemd
`DynamicUser`, `/var/lib/AdGuardHome` is a symlink into `/var/lib/private/...`
and the private tree is `0700 root` with the dynamic UID. The restic service
runs as root so it can read it, but: the dynamic UID is not stable across
reboots, so a _restore_ writes files owned by whatever UID restic recorded,
which will not match the next boot's DynamicUser UID, and AdGuard may refuse to
start or silently recreate state. This is a classic DynamicUser-backup trap.

Fix direction: back up via a pre-backup hook that copies AdGuard state to a
neutral staging dir (or use AdGuard's own config export), and restore into the
live path letting systemd re-own it. Document the restore caveat.

### P1-8 — No tested / documented restore procedure for restic, and the repo URL + password are both single sops secrets with no off-box copy

`hosts/homeserver-gcp/CLAUDE.md` documents backup _creation_ thoroughly but
has **no restore runbook**. `restic_password`, `restic_repository`, and
`b2_credentials` are sops secrets decryptable only by `&homeserver_gcp_host`
and `&user` (`.sops.yaml:26-30`). If the GCE disk is lost, recovery depends on
the operator's personal age key (`&user`) being available off-box — which it
is (it's the human key), so this is OK — but there is no written "given a fresh
VM, here's how to `restic restore` Vaultwarden" procedure. For a password
manager this is the most important runbook and it's missing.

Fix direction: add a `## Restore` section to the host CLAUDE.md with the exact
`restic restore latest --target /` flow, the secret-decrypt steps, and the
Grafana SQLite / AdGuard DynamicUser caveats from P0-5/P1-7. Better: a periodic
_restore test_ (even into a tmpdir) as a systemd timer that alerts on failure.

### P1-9 — `tailscale-cert` failure degrades nginx to a hard down, with no alert distinguishing "cert expired" from "service down"

`tailscale-cert.nix` fetches the cert; `grafana.nix:48-57` makes nginx
`requires=tailscale-cert.service`. If `tailscale cert` fails (rate limit, tailnet
HTTPS disabled, clock skew), `tailscale-cert.service` fails → nginx won't
(re)start. The daily renewal timer (`tailscale-cert.nix:44-47`) reloads nginx
only if the cert refresh _succeeds_; a failed renewal does **not** alert
specifically — it surfaces only as the generic `SystemdUnitFailed` alert
(which goes to the null receiver, P0-2). There is also no monitoring of the
cert's _expiry_. If renewal silently fails for ~90 days the cert expires and
all HTTPS breaks at once.

Fix direction: add a blackbox `ssl`-module probe (or node-exporter textfile
metric of `openssl x509 -enddate`) so cert expiry is a first-class alert with
days-remaining, independent of the unit's exit status. The blackbox http probes
already exist (`default.nix:96-115`) — add a TLS-expiry probe.

### P1-10 — nginx access log retention / format is the stock default; insufficient for incident response

The brief asks whether the access log captures enough for IR. `nginx.nix` does
not customize `log_format` or set up structured/JSON logging, nor ship access
logs to Loki (the audit collector only ships journald: sshd, sudo, service
failures — `collectors.nix:351-367`). nginx access logs go to
`/var/log/nginx/access.log` and are _not_ in the audit stream, so a request to
Vaultwarden or the ingest endpoints is not centrally searchable and rotates
away locally. For an internet-adjacent proxy this is a real IR gap.

Fix direction: add an nginx access-log Loki source (Alloy `loki.source.file`
or switch nginx to log via journald/syslog and add an audit source with
`SYSLOG_IDENTIFIER=nginx`), with a JSON `log_format` capturing
`$remote_addr $request $status $http_user_agent $request_time`.

### P1-11 — Installer enables `PermitRootLogin = "yes"` and root key auth with no fail2ban and a broad firewall

`hosts/installer/default.nix:9-16`: the installer opens TCP/22 globally
(`allowedTCPPorts = [ 22 ]`), enables sshd with `PermitRootLogin = "yes"`, and
authorizes root keys from `lib/pubkeys.nix`. The shared `security.nix` profile
is **not imported** by the installer, so there is _no_ fail2ban, no
PasswordAuthentication=false hardening, no kernel sysctl hardening. An
installer ISO is short-lived, but if it's ever booted on a network it's an
open root-SSH box. Key-only auth mitigates brute force, but PermitRootLogin yes

- no PasswordAuthentication override means it inherits NixOS installer defaults
  (which _do_ allow password login on the minimal ISO unless overridden).

Fix direction: set `services.openssh.settings.PasswordAuthentication = false`
explicitly in the installer, and consider importing the kernel-hardening sysctls.
At minimum confirm the installer never carries a password-login path.

---

## P2 — Optimizations / correctness hardening

### P2-1 — `recommendedProxySettings` + Vaultwarden `DOMAIN` mismatch risk on the NAT name

`default.nix:173` sets `DOMAIN = https://<tailnetFQDN>`. If a client ever
reaches Vaultwarden via the GCE NAT IP/name (possible until P0-1 is fixed),
WebAuthn/U2F origin checks will fail against the tailnet DOMAIN. Functionally
this _enforces_ tailnet-only access for passkeys, which is fine, but it's an
implicit dependency worth noting.

### P2-2 — Loki/Tempo/Mimir on the 50 GB root with no isolated quota

`hosts/homeserver-gcp/CLAUDE.md` (Disk Layout) explicitly chose root-only.
`DiskUsageHigh` fires at 80% (alerts.nix:34) → null receiver (P0-2), so a
telemetry-churn disk-fill takes down Vaultwarden writes silently. Loki
retention is 30 d, Mimir/Tempo bounded too, but Prometheus local retention is
24 h (collectors.nix:450) and node-exporter textfiles are tiny — main risk is
Loki chunk growth. Once P0-2 is fixed this is monitored; flagged as the most
likely real-world disk-fill source.

### P2-3 — `homepage-status` SSE server and status JSON expose internal topology unauthenticated over the tailnet

`status-page.nix` + `nginx.nix:114-140`: `/home/status.json`,
`/home/status.events`, `/home/status.svg` are served with **no** auth. They
expose failed unit names, full tailnet device inventory (hostnames, DNS names,
OS, online state — `status-page.nix:225-253`), system revisions, and audit
scores. Any tailnet device can read the entire fleet topology and security
posture. For a single-operator tailnet this is low risk, but it is more
internal detail than a status page needs to leak.

Fix direction: drop the tailnet device inventory and failed-unit _names_ from
the public JSON (keep counts), or gate `/home/*` behind the same
auth_request/tailscale-whois mechanism used for Grafana.

### P2-4 — `vulnix-scan` and `lynis-audit` write metrics but the scans run on _every_ host that imports the profile only here; coverage is single-host

`audits.nix` is homeserver-only. `main` has its own. Fine, but the CVE/Lynis
_alerts_ (alerts.nix) are global rules keyed on `instance` — confirm `main`'s
metrics also reach Mimir so the alert isn't silently single-host. (Out of this
domain's strict scope but worth a cross-check.)

### P2-5 — `restic-check-b2` and `restic-backups-b2` can overlap; no `Conflicts=`/ordering

Both run on independent timers (daily backup with 30 m jitter via backup.nix;
weekly check with 2 h jitter). A check reading the repo while a backup writes
is generally safe with restic locking, but a long check can block a backup's
lock and the backup will fail → with P0-4's false-green metric, you won't know.

Fix direction: add `After=`/`Conflicts=` between the two units, or rely on
restic lock + ensure the (fixed, post-P0-4) metric correctly reports the
lock-failure.

---

## P3 — Future additions

- **P3-1** — Real alert delivery (ntfy/Pushover/email) — see P0-2; this is the
  highest-value addition.
- **P3-2** — TLS-expiry blackbox probe + cert age dashboard panel (P1-9).
- **P3-3** — Automated restic restore-test timer into a scratch dir, emitting a
  `restic_last_restore_test_timestamp_seconds` metric + alert (P1-8).
- **P3-4** — Declarative AdGuard (`mutableSettings = false`) with blocklists and
  sops-sourced admin creds (P1-4).
- **P3-5** — nginx access logs → Loki with JSON log_format (P1-10).
- **P3-6** — GCP edge firewall hardening as code, ideally a dedicated VPC
  (P0-1).
- **P3-7** — Grafana SQLite consistent-snapshot pre-backup hook (`VACUUM INTO`)
  (P0-5).
- **P3-8** — `Shielded VM` / Secure Boot + vTPM and OS Login disable for the GCE
  instance (currently `google_compute_instance` has no `shielded_instance_config`).
- **P3-9** — Metadata endpoint hardening: the startup script reads instance
  metadata; once provisioned, consider `block-project-ssh-keys=TRUE` and
  confirm no service in-guest can reach `169.254.169.254` it shouldn't (the
  status page and probes hit only loopback, good).
