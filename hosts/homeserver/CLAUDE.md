# Homeserver Host

Headless server running Vaultwarden, Syncthing, Tailscale, Nginx.
Accessible via Tailscale at `homeserver.filip-nowakowicz.ts.net`.

## Services

- **Vaultwarden** — `127.0.0.1:8222`, proxied via Nginx over HTTPS
- **Syncthing** — web UI via SSH tunnel: `ssh -L 8384:localhost:8384 homeserver`
- **Nginx** — reverse proxy, TLS via Tailscale cert (not ACME)
- **Tailscale** — auth key from sops secret `tailscale_auth_key`

## First Deploy Checklist

Hardware not yet provisioned. Steps in order:

1. **Replace hardware config** — run `nixos-generate-config` on target or use `nixos-anywhere --generate-hardware-config`
2. **Set Tailscale auth key** — `sops hosts/homeserver/secrets/secrets.yaml`, set `tailscale_auth_key` (Tailscale admin → Settings → Keys → reusable + ephemeral)
3. **Deploy** — `deploy '.#homeserver'` (or `nix run '.#reinstall-homeserver' <target-ip>` for fresh install)
4. **Add host age key to sops** — after first boot:
   ```
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub  # run on homeserver
   ```
   Add result under `&homeserver_host` in `.sops.yaml`, then:
   `sops updatekeys hosts/homeserver/secrets/secrets.yaml`
5. **Create Vaultwarden account** — temporarily set `SIGNUPS_ALLOWED = true`, deploy, create account at `https://homeserver.filip-nowakowicz.ts.net`, set back to `false`, deploy again

## Architecture

- **Config**: `hosts/homeserver/default.nix` — imports `modules/nixos/profiles/observability.nix` (full stack)
- **Registry**: `lib/hosts.nix` — single source of truth for role, tailnet FQDN, and backup class
- **Secrets**: `hosts/homeserver/secrets/secrets.yaml` — decrypted using host SSH key
- **Observability**: `lib/generators.nix` and `lib/dashboards.nix` drive Alloy and Grafana config
- **Syncthing Configuration**: Syncthing devices/folders are declarative and shared with `homeserver-vm` via `lib/syncthing.nix`.
  `overrideDevices` and `overrideFolders` are enabled so the host always converges to that validated config.

## Gotchas

- **TLS cert is not ACME** — `tailscale-cert.service` fetches it; nginx depends on that service. Don't configure `enableACME`.
- **nginx starts after tailscale-cert** — first boot may take a minute for cert to be provisioned.
- **Impermanence** — `/var/lib/vaultwarden`, `/var/lib/syncthing`, `/var/lib/tailscale` are persisted; everything else resets on reboot.
- **Sops decryption requires host key** — host's SSH key must be added to `.sops.yaml` _before_ secrets can be decrypted on boot. The reinstall script injects a pre-generated host key to ensure this from first boot.
