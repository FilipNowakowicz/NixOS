# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate next steps to longer-term directions.

---

## Active

- **LGTM tuning**: Expand dashboards/alerts and tune retention/cardinality for long-running operation. Add alerting rules for disk usage >80%, service restarts, and backup failures.

---

## Next Up

- [ ] **Homeserver on real hardware** — generate hardware config, provision Tailscale auth key, add host age key to `.sops.yaml`, deploy, create first Vaultwarden account. Full checklist in `hosts/homeserver/CLAUDE.md`.
- [ ] **Off-site backup (B2)** — replace local-only restic repository on homeserver with Backblaze B2. Add sops secret for B2 credentials (`B2_ACCOUNT_ID` + `B2_ACCOUNT_KEY`), update repository URL. Local backup on `main` can follow the same pattern later.

---

## Future Directions

- [ ] **Nix binary cache** — self-hosted `nix-serve` on the homeserver or Cachix. Saves rebuild time once multiple machines share the same flake. Especially valuable if CI starts building closures.
- [ ] **Secrets rotation automation** — a flake app or script that rotates common secrets (Grafana admin, observability ingest password, Tailscale auth key) and redeploys, reducing manual toil.
- [ ] **CI smoke test scheduling** — the `homeserver-vm-smoke` NixOS test is expensive. Run it on a schedule (weekly) or only when homeserver-related paths change, rather than on every push.
- [ ] **Portable home-manager** — use the standalone `homeConfigurations.user` for non-NixOS machines (work laptop, WSL, Nix-on-Droid). The current structure already supports this.
- [ ] **Local DNS & ad-blocking** — deploy AdGuard Home or Pi-hole on the homeserver, integrated with Tailscale for network-wide privacy.
- [ ] **Hardware security keys (YubiKey)** — YubiKey-backed PAM for login/sudo and hardware-backed SSH keys (`sk-ecdsa`) to eliminate file-based private keys.
- [ ] **AQ_DRM_DEVICES stability** — replace `/dev/dri/card1` with a udev rule that creates a stable symlink, so the GPU assignment survives kernel updates.

---
