# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate implementation tasks to long-term architectural research.

---

## Active & Pending

### 2. Infrastructure & Observability
3. - [ ] **LGTM Stack (Loki, Grafana, Tempo, Mimir)**: Implement centralized logging and metrics for all NixOS nodes. Visualize system health, temps, and traffic in a single dashboard on the `homeserver`.
4. - [ ] **Declarative Backups (Restic)**: Configure `services.restic` to automate encrypted, deduplicated backups of `/persist` volumes to offsite storage (B2/R2) with automated pruning and health checks.

### 3. Security Hardening & Identity
2. - [ ] **Advanced Service Sandboxing**: Systematically audit systemd services to apply strict security wrappers like `ProtectSystem=strict`, `PrivateTmp=true`, and `CapabilityBoundingSet`.

### 4. Advanced Nix Ecosystem
1. - [x] **NixOS Integration Tests**: Learn the `nixosTest` framework to write Python-based integration tests.
    *   Implemented: `checks.x86_64-linux.homeserver-vm-smoke` for Vaultwarden/Nginx/Syncthing smoke coverage.
    *   Next step: expand to multi-node (`homeserver` + `client`) proxy/network behavior tests.

### 5. Design
- [ ] **Waybar**: Extra Icons
- [ ] **eww Widgets**: Research and implement floating dashboard widgets (currently deferred).

<!-- ### 6. Homeserver on Hardware -->
<!---->
<!-- - [ ] **Generate hardware config** — boot installer ISO on real hardware, run `nixos-generate-config`, copy result to `hosts/homeserver/hardware-configuration.nix` -->
<!-- - [ ] **Provision Tailscale auth key** — Tailscale admin → Settings → Keys → reusable + ephemeral, add to `hosts/homeserver/secrets/secrets.yaml` via `sops` -->
<!-- - [ ] **Add host age key to sops** — pre-generate SSH host key, convert with `ssh-to-age`, add under `&homeserver_host` in `.sops.yaml`, then `sops updatekeys hosts/homeserver/secrets/secrets.yaml` -->
<!-- - [ ] **Initial deploy** — `nix run '.#reinstall-homeserver' <target-ip>` for fresh install, or `deploy .#homeserver` if NixOS already running -->
<!-- - [ ] **Vaultwarden — first account on real hardware** — same flow as VM phase: temporarily set `SIGNUPS_ALLOWED = true`, create account at `https://homeserver.filip-nowakowicz.ts.net`, lock back down -->
<!-- - [ ] **Verify Tailscale cert** — nginx depends on `tailscale-cert.service`; first boot may take a minute for cert provisioning -->


<!-- - [ ] **Local DNS & Ad-blocking**: Deploy `AdGuard Home` or `Pi-hole` on the `homeserver`, integrated with Tailscale to provide network-wide privacy for all connected devices. -->
<!-- - [ ] **Micro-segmentation**: Use Tailscale ACLs and the NixOS firewall to enforce a "Zero Trust" architecture between internal services (e.g., Vaultwarden only accessible via the Nginx proxy). -->
<!-- - [ ] **Hardware Security Keys (YubiKey)**: Implement YubiKey-backed PAM for local login/sudo and transition to hardware-backed SSH keys (sk-ecdsa) to eliminate file-based private keys. -->
---
