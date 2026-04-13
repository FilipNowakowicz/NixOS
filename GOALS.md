# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate implementation tasks to long-term architectural research.

---

## Active & Pending

### In Progress
- [ ] **Homeserver Hardware Deployment**: Transition from VM stubs to real hardware.
    - [ ] Replace `hardware-configuration.nix` with real values.
    - [ ] Provision Tailscale auth key and wire into sops.
    - [ ] Initial `deploy .#homeserver`.
    - [ ] Add host age key to `.sops.yaml` and re-encrypt.
- [ ] **Vaultwarden Setup**: Complete first-user registration and lock down signups.

### Pending UI/UX
- [ ] **Waybar Redesign**: Comprehensive visual overhaul.
- [ ] **eww Widgets**: Research and implement floating dashboard widgets (currently deferred).

---

## Research & Future Exploration

### 1. Infrastructure & Observability
- [ ] **LGTM Stack (Loki, Grafana, Tempo, Mimir)**: Implement centralized logging and metrics for all NixOS nodes. Visualize system health, temps, and traffic in a single dashboard on the `homeserver`.
- [ ] **Declarative Backups (Restic)**: Configure `services.restic` to automate encrypted, deduplicated backups of `/persist` volumes to offsite storage (B2/R2) with automated pruning and health checks.
- [ ] **Local DNS & Ad-blocking**: Deploy `AdGuard Home` or `Pi-hole` on the `homeserver`, integrated with Tailscale to provide network-wide privacy for all connected devices.

### 2. Security Hardening & Identity
- [ ] **Hardware Security Keys (YubiKey)**: Implement YubiKey-backed PAM for local login/sudo and transition to hardware-backed SSH keys (sk-ecdsa) to eliminate file-based private keys.
- [ ] **Advanced Service Sandboxing**: Systematically audit systemd services to apply strict security wrappers like `ProtectSystem=strict`, `PrivateTmp=true`, and `CapabilityBoundingSet`.
- [ ] **Micro-segmentation**: Use Tailscale ACLs and the NixOS firewall to enforce a "Zero Trust" architecture between internal services (e.g., Vaultwarden only accessible via the Nginx proxy).

### 3. Advanced Nix Ecosystem
- [ ] **NixOS Integration Tests**: Learn the `nixosTest` framework to write Python-based integration tests.
    *   *Example:* Spin up a virtual network with a `homeserver` and `client` VM to verify that Nginx correctly proxies traffic to Vaultwarden before every deployment.

---

## Cold Storage (Deferred/Won't Do)
- **Impermanence on `main`**: Attempted and reverted. The friction of managing a daily driver with an ephemeral root is currently too high for the perceived security benefit.
