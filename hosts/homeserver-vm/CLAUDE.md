# Homeserver VM — Development Target

NixOS VM running homeserver services for testing and development before hardware arrives.
Configured with Vaultwarden and Syncthing (same as real homeserver), but without Tailscale/Nginx/TLS.

Deploy with: `deploy .#homeserver-vm` (after `nix run '.#reinstall-vm'` on first setup)

## Services Running

- **Vaultwarden** — accessible at `http://127.0.0.1:8222`
- **Syncthing** — web UI via SSH tunnel: `ssh -L 8384:localhost:8384 nixvm`
- **SSH** — for deployment and remote access

## Differences from Real Homeserver

- No Tailscale — not applicable to a VM
- No Nginx reverse proxy — Vaultwarden accessible directly on port 8222
- No TLS certificates — test with HTTP only
- Simpler networking (NetworkManager) — no systemd-networkd
- Uses standard home.nix instead of home-server.nix

## Testing Workflow

1. **Deploy VM**: `nix run '.#reinstall-vm'` (one-time setup)
2. **Test homeserver config**: `deploy .#homeserver-vm`
3. **SSH in**: `ssh nixvm` (via alias in `~/.ssh/config`)
4. **Access services**:
   - Vaultwarden: `curl http://127.0.0.1:8222`
   - Syncthing: `ssh -L 8384:localhost:8384 nixvm` then `localhost:8384` in browser
5. **Iterate**: Make config changes to `hosts/homeserver/default.nix` and test with `deploy .#homeserver-vm`

## Notes

- Vaultwarden database and Syncthing data are persisted to `/persist` — they survive VM reboots
- When ready to deploy to real hardware, use `hosts/homeserver/` config directly (adds Tailscale, Nginx, TLS)
- Both homeserver and homeserver-vm import the same security/server profiles — differences are only in networking and service exposure
