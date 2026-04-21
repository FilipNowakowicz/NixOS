# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

- [ ] **Security hardening (phased)** — Apply defense-in-depth practices to main machine and systems. Start with main machine (kernel hardening, service isolation, reduced attack surface), then expand to VMs as needed. Document hardening rationale and learn through hands-on pentesting against hardened systems.

---

## Future Directions

- [ ] **Quality of life on main** — Improve observability, reliability, and maintainability of main machine. Explore: monitoring & alerting, automated maintenance, resource optimization, update strategy, graceful failure handling. Discover what's worth improving as you go.

---

## Accomplished

- [x] **Host Registry (Data-driven configuration)** — Generalized host management into `lib/hosts.nix`. All hosts (main, homeserver, VMs) are defined in one place, driving `nixosConfigurations`, `deploy-rs` nodes, and VM management scripts.
- [x] **Typed Config Generators** — Implemented `lib/generators.nix` (Alloy HCL) and `lib/dashboards.nix` (Grafana JSON via Nix attrsets). Replaced ugly string heredocs with type-safe, testable Nix code.
- [x] **Continuous Validation** — Added configuration invariant checks (`lib/invariants.nix`) to assert system state (e.g., firewall status, sudo permissions). Integrated `statix`, `deadnix`, and `closure-diff` into CI.
- [x] **Unified Formatting** — Unified `nixfmt`, `shfmt`, and `prettier` behind `nix fmt` using `treefmt-nix`.
- [x] **Pre-commit Hooks** — Automated quick checks (nixfmt, statix, deadnix, plaintext secret guard) via `pre-commit-hooks.nix`.
- [x] **Automated Maintenance** — Scheduled GC and auto-optimise-store enabled on `main` via `modules/nixos/profiles/base.nix`.

---

## Deferred

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.
- [ ] **Automated deploy pipeline (requires real homeserver)** — CI already builds all closures and pushes to Cachix, smoke test runs on relevant path changes. Remaining: add a self-hosted GitHub Actions runner as a NixOS service on the homeserver (always-on, has KVM), extend smoke test to probe live endpoints (Grafana login, ingest auth), add automated deploy job that deploys homeserver then main in order after smoke test passes. Secrets rotation (ingest credentials, Grafana admin password) becomes a cheap add-on once deploy is automated — Tailscale auth key stays manual.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home or Pi-hole on the homeserver, integrated with Tailscale for network-wide privacy.
- [ ] **LGTM tuning**: Expand dashboards/alerts and tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.
- console.cloud.google.com (Cloud Homeserver?)

---
