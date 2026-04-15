# Project Roadmap & Goals

This document tracks the evolution of this NixOS configuration, from immediate implementation tasks to long-term architectural research.

---

## Active & Pending

<!-- ### 5. Design -->
<!-- - [ ] **Waybar**: Extra Icons -->
<!-- - [ ] **eww Widgets**: Research and implement floating dashboard widgets (currently deferred). -->

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
- LGTM Next step: expand dashboards/alerts and tune retention/cardinality for long-running operation.
---
