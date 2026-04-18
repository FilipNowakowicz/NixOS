# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

_Nothing in progress._

---

## Future Directions

_Nothing in progress._

---

## Deferred

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.
- [ ] **Automated deploy pipeline (requires real homeserver)** — CI already builds all closures and pushes to Cachix, smoke test runs on relevant path changes. Remaining: add a self-hosted GitHub Actions runner as a NixOS service on the homeserver (always-on, has KVM), extend smoke test to probe live endpoints (Grafana login, ingest auth), add automated deploy job that deploys homeserver then main in order after smoke test passes. Secrets rotation (ingest credentials, Grafana admin password) becomes a cheap add-on once deploy is automated — Tailscale auth key stays manual.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home or Pi-hole on the homeserver, integrated with Tailscale for network-wide privacy.
- [ ] **LGTM tuning**: Expand dashboards/alerts and tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.
- console.cloud.google.com
---

