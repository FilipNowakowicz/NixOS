# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

### Config Dashboard

The local inventory page already gives a good host-level view of the flake. The
next step is to turn it into a better operator surface by separating manual
roadmap items from computed config findings.

- [x] **Config dashboard wave 1** (medium) -- redesign `nix build '.#inventory'`
  around a structured goals board plus a separate computed attention panel. Add
  machine-readable goals data, goal status groupings, and links back to
  canonical docs. Detailed plan: `docs/config-dashboard.md`.
- [ ] **Config dashboard wave 2** (medium) -- add validation commands,
  dependency context, and goal-to-host/service relationships so the dashboard
  shows not just what matters, but how to act on it.
- [ ] **Config dashboard wave 3** (medium) -- add closure-size, invariant, and
  validation-health signals so the dashboard exposes cost, drift, and proof of
  health alongside inventory and roadmap state.

### Homeserver

The homeserver modules are already hardware-agnostic. Two paths forward — GCP unblocks the deferred pile without waiting on physical hardware.

### Path A — GCP (cloud homeserver, unblocks deferred items)

- [ ] **GCP homeserver** (medium–substantial) — build a GCE image from the existing homeserver config (`nixos-generators -f gce`), push to GCS, boot via Terraform/OpenTofu. Join tailnet as a subnet router. Unlocks everything below.

### Path B — Real hardware (blocked)

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.

### Deferred (either path unlocks these)

- [ ] **Automated deploy pipeline** — add a self-hosted GitHub Actions runner as a NixOS service on the homeserver (always-on, has KVM). Extend smoke test to probe live endpoints (Grafana login, ingest auth). Add automated deploy job that deploys homeserver then main in order after smoke test passes. CI already builds all closures and pushes to Cachix. Secrets rotation (ingest credentials, Grafana admin password) becomes a cheap add-on once deploy is automated — Tailscale auth key stays manual.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home on the homeserver (or GCE VM), integrated with Tailscale MagicDNS for network-wide privacy.
- [ ] **LGTM tuning** — expand dashboards and alerts, tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.
- [ ] **Host introspection → LGTM** (medium) — auditd + osquery or lynis timer → logs to Loki → dashboards. Pairs with the existing observability stack; proves the LGTM investment for something beyond infra metrics.
- [ ] **Service composition DSL** (medium–substantial) — a module like `services.app.<name> = { package, port, backup, observe, harden }` that auto-wires sandboxing, systemd hardening, log shipping, and restic targets. Eliminates the "add a service → remember to also wire 5 cross-cutting things" tax.
- [ ] **Expand typed generator approach to additional domains (for example nginx vhosts/timers).**
- [ ] **Create secret rotation ritual/checklist + age/rotation observability metric.**
