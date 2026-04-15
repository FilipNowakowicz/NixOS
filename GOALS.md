# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate implementation tasks to long-term architectural research.

---

## Active & Pending

### 1. Homeserver

**Strategy**: develop and validate everything on `homeserver-vm` (same VM as dev), then deploy to real hardware with minimal changes. `hosts/homeserver-vm/` mirrors `hosts/homeserver/` but without Tailscale/Nginx/TLS.

- [ ] **Syncthing — bootstrap**
    - `ssh -L 8384:127.0.0.1:8384 homeserver-vm` then open `http://localhost:8384`
    - Get device ID: `ssh homeserver-vm syncthing cli show system | grep myID`
    - Add peer device IDs to `lib/syncthing.nix`, set `overrideDevices/Folders = true`, redeploy
- [ ] **Validate impermanence** — reboot VM (`ssh homeserver-vm sudo reboot`), confirm Vaultwarden data and Syncthing config survive
- [ ] **Mirror validated config to `hosts/homeserver/`** — apply any changes made during VM testing to the real homeserver config

### 2. Infrastructure & Observability
- [ ] **LGTM Stack (Loki, Grafana, Tempo, Mimir)**: Implement centralized logging and metrics for all NixOS nodes. Visualize system health, temps, and traffic in a single dashboard on the `homeserver`.
- [ ] **Declarative Backups (Restic)**: Configure `services.restic` to automate encrypted, deduplicated backups of `/persist` volumes to offsite storage (B2/R2) with automated pruning and health checks.
- [ ] **Local DNS & Ad-blocking**: Deploy `AdGuard Home` or `Pi-hole` on the `homeserver`, integrated with Tailscale to provide network-wide privacy for all connected devices.

### 3. Security Hardening & Identity
- [ ] **Hardware Security Keys (YubiKey)**: Implement YubiKey-backed PAM for local login/sudo and transition to hardware-backed SSH keys (sk-ecdsa) to eliminate file-based private keys.
- [ ] **Advanced Service Sandboxing**: Systematically audit systemd services to apply strict security wrappers like `ProtectSystem=strict`, `PrivateTmp=true`, and `CapabilityBoundingSet`.
- [ ] **Micro-segmentation**: Use Tailscale ACLs and the NixOS firewall to enforce a "Zero Trust" architecture between internal services (e.g., Vaultwarden only accessible via the Nginx proxy).

### 4. Advanced Nix Ecosystem
- [ ] **NixOS Integration Tests**: Learn the `nixosTest` framework to write Python-based integration tests.
    *   *Example:* Spin up a virtual network with a `homeserver` and `client` VM to verify that Nginx correctly proxies traffic to Vaultwarden before every deployment.

### 5. Design
- [ ] **Waybar**: Extra Icons
- [ ] **eww Widgets**: Research and implement floating dashboard widgets (currently deferred).

### 6. Homeserver on Hardware

- [ ] **Generate hardware config** — boot installer ISO on real hardware, run `nixos-generate-config`, copy result to `hosts/homeserver/hardware-configuration.nix`
- [ ] **Provision Tailscale auth key** — Tailscale admin → Settings → Keys → reusable + ephemeral, add to `hosts/homeserver/secrets/secrets.yaml` via `sops`
- [ ] **Add host age key to sops** — pre-generate SSH host key, convert with `ssh-to-age`, add under `&homeserver_host` in `.sops.yaml`, then `sops updatekeys hosts/homeserver/secrets/secrets.yaml`
- [ ] **Initial deploy** — `nix run '.#reinstall-homeserver' <target-ip>` for fresh install, or `deploy .#homeserver` if NixOS already running
- [ ] **Vaultwarden — first account on real hardware** — same flow as VM phase: temporarily set `SIGNUPS_ALLOWED = true`, create account at `https://homeserver.filip-nowakowicz.ts.net`, lock back down
- [ ] **Verify Tailscale cert** — nginx depends on `tailscale-cert.service`; first boot may take a minute for cert provisioning
---
