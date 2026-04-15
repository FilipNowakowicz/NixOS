# Homeserver VM — Development Target

NixOS VM running homeserver services for testing and development before hardware arrives.
Configured with Vaultwarden and Syncthing (same as real homeserver), but without Tailscale/Nginx/TLS.

## Quick Reference

```bash
nix run '.#vm' -- create homeserver-vm    # Full setup
deploy '.#homeserver-vm'                    # Deploy config changes
ssh homeserver-vm                         # SSH into the VM (port 2223)
```

## Services Running

- **Vaultwarden** — accessible at `http://127.0.0.1:8222` (inside VM)
- **Syncthing** — web UI via SSH tunnel: `ssh -L 8384:localhost:8384 homeserver-vm`
- **SSH** — for deployment and remote access

## Differences from Real Homeserver

- No Tailscale — not applicable to a VM
- Nginx with self-signed TLS cert (not Tailscale cert) — Vaultwarden proxied on port 8443
- Uses NetworkManager (not systemd-networkd)
- Uses home-server.nix (same as real homeserver)

## Testing Workflow

1. **Create VM**: `nix run '.#vm' -- create homeserver-vm`
2. **Deploy changes**: `deploy '.#homeserver-vm'`
3. **Verify Vaultwarden**: `ssh homeserver-vm curl http://127.0.0.1:8222`
4. **Access Syncthing**: `ssh -L 8384:localhost:8384 homeserver-vm` then `localhost:8384` in browser
5. **Iterate**: edit config, `deploy '.#homeserver-vm'`, test

## Architecture

- **Config**: `hosts/homeserver-vm/default.nix` — imports shared `modules/nixos/profiles/vm.nix`
- **Registry**: `lib/vm.nix` — SSH port 2223, disk size 20G
- **Secrets**: `hosts/homeserver-vm/secrets/` — own host key, separate from `vm`
- **Disk images**: `~/.local/share/nixos-vms/homeserver-vm.qcow2`

## Notes

- Runs on its own QEMU instance (port 2223) — can run simultaneously with `vm` (port 2222)
- Vaultwarden database and Syncthing data are persisted to `/persist` — survive reboots
- When ready for real hardware, use `hosts/homeserver/` config directly (adds Tailscale, Nginx, TLS)
