# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

### Goal 01 — Desktop "daily driver" profile

Turn `main` into a more intentional workstation layer. Tackled incrementally — each item is independent and shippable on its own.

#### Ready to implement

- [ ] **Bluetooth menu** — replace Blueman (half-screen app) with a `bluetoothctl`-driven `fuzzel` popup: lists paired devices, click to connect/disconnect.
- [ ] **WiFi menu** — replace `networkmanagerapplet` tray with an `nmcli`-driven `fuzzel` popup launched from the Waybar network module.
- [ ] **Volume menu** — Waybar audio module opens a thin custom popup for output/input switching (via `wpctl` or `pavucontrol`), separate from the OSD.

#### Needs design discussion

- [ ] **App launcher** — existing launchers (wofi, rofi, fuzzel) all available; design direction TBD.
- [ ] **Spotify/MPRIS controls in Waybar** — show current track, pause/skip via `playerctl`. Must filter to music players only (exclude browsers, video). Design and allowlist TBD.
- [ ] **Clipboard history GUI** — `cliphist` + `fzf` already works; upgrade to a `fuzzel`-based picker for consistency with other menus.

#### Deferred (low urgency or blocked on discussion)

- [ ] **Idle inhibitor toggle** — Waybar button that pauses `hypridle` (e.g. when watching something outside a browser).
- [ ] **Do-not-disturb toggle** — `makoctl mode +dnd` wired to a Waybar button; silences notifications on demand.
- [ ] **GTK/cursor/icon theming** — wire `gtk.theme`, `cursorTheme`, and an icon pack (e.g. Papirus) through home-manager so all apps match the active theme. Discuss alongside theme studio.
- [ ] **Screenshot workflow** — `satty` for annotation after `grim` capture; `tesseract` OCR pipeline outputting to clipboard.
- [ ] **Keybinding cheat sheet** — auto-generated popup from `hyprland.conf` binds, shown via `Super+?`.

### Homeserver (GCP)

`homeserver-gcp` is the active homeserver running on GCP (GCE, e2-medium, `us-central1`). Vaultwarden, LGTM stack, Nginx with Tailscale-issued TLS, and Backblaze B2 backups are all live. Provisioning is end-to-end automated via `scripts/deploy-gcp.sh` (sops → OpenTofu → nixos-anywhere); SSH host key bootstrap is automatic via GCE instance metadata.

#### Operational hardening

- [ ] **Automated deploy pipeline** — stand up a self-hosted GitHub Actions runner as a NixOS service. Decision needed: run it on `main` (already has KVM, suitable for NixOS VM tests, but not always-on), on `homeserver-gcp` after upgrading to a nested-virt-capable instance type (`n2-standard-2` or similar; `e2` does **not** support KVM), or split — keep build/lint/flake-check on the GCP runner without KVM, run VM tests on `main`. Extend smoke test to probe live endpoints (Grafana login, ingest auth). Add a deploy job that rolls homeserver-gcp then main in sequence after smoke tests pass.
- [ ] **Secret rotation ritual** — checklist + cadence per secret (Tailscale auth key remains manual; ingest credentials, Grafana admin password, restic password rotate via the deploy pipeline once it lands). Surface "days since last rotation" as a Grafana panel, with alerts when over policy.
- [ ] **LGTM tuning** — expand dashboards and alerts, tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts (`systemd-failure-notify` already covers this — wire it into Grafana too), and restic backup failure/age (`restic_backup_last_success_seconds`).
- [ ] **Backup posture** — either set `backup.class = "critical"` for `homeserver-gcp` and have `services.restic.backups.b2` consume the typed retention from `modules/nixos/profiles/backup.nix`, or keep the override but document the policy split. Add a periodic `restic check --read-data-subset=1G` timer to detect bit-rot, and a quarterly restore drill.
- [ ] **Disk layout cleanup** — the disko spec carries an unused `/persist` partition (~19.5 GB). Either retire it (root takes 100%) or use it for things that benefit from a separate fs (Loki/Mimir blocks, restic cache).

#### New capabilities

- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home on the GCE VM, integrated with Tailscale MagicDNS for network-wide privacy. Export AdGuard metrics to Mimir for query/block visibility.
- [ ] **Host introspection → LGTM** (medium) — auditd + osquery or lynis timer → logs to Loki → dashboards. Pairs with the existing observability stack; proves the LGTM investment for something beyond infra metrics.
- [ ] **Vaultwarden websocket / push** — enable the websocket notification path so mobile clients get instant sync; add an Nginx location block for `/notifications/hub`.
- [ ] **Tailscale-aware SSO for Grafana** — drop the local admin password in favour of `tailscale serve` + `tailscale_auth_proxy` style identity headers, mapping Tailscale identity to Grafana org roles. Removes one rotating secret.
- [ ] **Vulnix + CVE dashboard for the live closure** — schedule a periodic `vulnix` run against `/run/current-system`, ship results as a JSON exporter to Mimir, alert on new criticals.

#### Architecture / refactors

- [ ] **Service composition DSL** (medium–substantial) — a module like `services.app.<name> = { package, port, backup, observe, harden }` that auto-wires sandboxing, systemd hardening, log shipping, and restic targets. Eliminates the "add a service → remember to also wire 5 cross-cutting things" tax. Vaultwarden + AdGuard would be the first two consumers.
- [ ] **Expand typed generator approach** — extend `lib/generators.nix` beyond Alloy HCL to nginx vhosts (typed `locations`, basic-auth, websocket bool) and systemd timers (`OnCalendar` schedule + jitter as a typed schema).
- [ ] **ACL drift detection** — schedule a CI job that diffs the rendered `tailscale-acl` package against the live policy via the Tailscale API and fails on drift. Already half-built (the package exists); just needs the API check.
- [ ] **Per-host snapshot of the GCE disk** — daily managed snapshot via OpenTofu schedule, retained 7 days. Cheap belt-and-braces alongside restic; restores in minutes vs. hours.
