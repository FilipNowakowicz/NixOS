# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

- **Automated deploy pipeline**: Build a CI/CD pipeline that pre-builds NixOS closures into a binary cache, runs the `homeserver-vm` smoke test before touching real hardware, and deploys hosts in the correct order (homeserver → main). Smoke test should probe live endpoints (Grafana login, ingest auth) not just check services start. Secrets rotation (ingest credentials, Grafana admin password) is a cheap add-on once the pipeline exists — one command regenerates credentials, commits updated sops files, and triggers the full pipeline. Tailscale auth key stays a manual step.

---

## Future Directions

- [ ] **Portable home-manager** — use the standalone `homeConfigurations.user` for non-NixOS machines (work laptop, WSL, Nix-on-Droid). The current structure already supports this.

---

## Deferred

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home or Pi-hole on the homeserver, integrated with Tailscale for network-wide privacy.
- [ ] **LGTM tuning**: Expand dashboards/alerts and tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.
- console.cloud.google.com
---

