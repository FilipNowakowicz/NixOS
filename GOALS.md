# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

- **Secrets rotation automation**: Build a manual flake app/script to rotate common secrets (Grafana admin, observability ingest password, Tailscale auth key). Test on `homeserver-vm`, design for easy conversion to systemd timer when moving to real hardware.

---

## Future Directions

- [ ] **Portable home-manager** — use the standalone `homeConfigurations.user` for non-NixOS machines (work laptop, WSL, Nix-on-Droid). The current structure already supports this.

---

## Deferred

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.
- [ ] **Nix binary cache** — self-hosted `nix-serve` on the homeserver or Cachix. Saves rebuild time once multiple machines share the same flake. Especially valuable if CI starts building closures.
- [ ] **CI smoke test scheduling** — the `homeserver-vm-smoke` NixOS test is expensive. Run it on a schedule (weekly) or only when homeserver-related paths change, rather than on every push.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home or Pi-hole on the homeserver, integrated with Tailscale for network-wide privacy.
- **LGTM tuning**: Expand dashboards/alerts and tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.
- console.cloud.google.com
---

