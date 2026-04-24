# Homeserver VM — Development Target

NixOS VM running homeserver services (Vaultwarden, Syncthing) for testing before
hardware deployment. Runs as a systemd service on `main` via microvm.nix.

## Quick Reference

```bash
nh os switch --hostname main .               # deploy config changes
ssh user@10.0.100.2                          # SSH into VM
sudo systemctl status microvm@homeserver-vm  # check VM status
sudo journalctl -u microvm@homeserver-vm -f  # watch VM logs
```

## Services

| Service     | URL (from main)         |
| ----------- | ----------------------- |
| Vaultwarden | https://10.0.100.2:8443 |
| Syncthing   | http://10.0.100.2:8384  |
| Grafana     | http://10.0.100.2:3000  |

**Cert Persistence**: The self-signed TLS certificate is generated once during the first boot and persists under `/persist`. If replacement is needed (e.g., due to expiration), it must be done manually on the guest filesystem.

## Differences from Real Homeserver

- No Tailscale
- Self-signed TLS cert (not Tailscale cert)
- Nginx proxies HTTPS on 8443 → Vaultwarden on 8222
- Networking via static IP on host-only bridge (10.0.100.0/24)

## Architecture

- **Config**: `hosts/homeserver-vm/default.nix` — imports `modules/nixos/profiles/microvm-guest.nix`
- **Host module**: `modules/nixos/microvms/homeserver-vm.nix` — imported by `hosts/main/default.nix`
- **Registry**: `lib/hosts.nix` — ip: 10.0.100.2
- **Secrets**: `hosts/homeserver-vm/secrets/` — age key held in main's sops secrets (`homeserver_vm_age_key`)
- **Persist volume**: `/var/lib/microvms/homeserver-vm/persist.img` on main

## Networking

- Bridge `microvm-br0` on main: 10.0.100.1
- VM static IP: 10.0.100.2
- NAT masquerading via main's WiFi for VM internet access
