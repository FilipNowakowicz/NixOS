# Homeserver Host

Headless server running Vaultwarden, Syncthing, Tailscale, Nginx.
Accessible via Tailscale at `homeserver.filip-nowakowicz.ts.net`.

## Services

- **Vaultwarden** — `127.0.0.1:8222`, proxied via Nginx over HTTPS
- **Syncthing** — web UI via SSH tunnel: `ssh -L 8384:localhost:8384 homeserver`
- **Nginx** — reverse proxy, TLS via Tailscale cert (not ACME)
- **Tailscale** — auth key from sops secret `tailscale_auth_key`

## Sops Bootstrap

The host SSH key is **pre-generated** and committed (encrypted) to the repo. This means
sops secrets are decryptable from first boot without any post-deploy manual step.

- Private key: `hosts/homeserver/secrets/ssh_host_ed25519_key.enc` (sops-encrypted)
- Public key: `hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc` (sops-encrypted)
- Age identity: `&homeserver_host` in `.sops.yaml` (derived from the above public key)

`nix build '.#checks.x86_64-linux.homeserver-sops-bootstrap'` enforces that both
encrypted files are present; it will fail-loud with instructions if they're missing.

## First Deploy Checklist

Hardware not yet provisioned. Steps in order:

1. **Replace hardware config** — run `nixos-generate-config` on target or use `nixos-anywhere --generate-hardware-config`
2. **Set Tailscale auth key** — `sops hosts/homeserver/secrets/secrets.yaml`, set `tailscale_auth_key` (Tailscale admin → Settings → Keys → reusable + ephemeral)
3. **Deploy** — `nix run '.#reinstall-homeserver' -- <target-ip>` (injects pre-baked host key via nixos-anywhere)
4. **Create Vaultwarden account** — This is a one-time bootstrap operation. Set `SIGNUPS_ALLOWED = true` in the configuration, deploy, and create your account at `https://homeserver.filip-nowakowicz.ts.net`. **Immediately** set it back to `false` and redeploy. Access is assumed to be Tailscale-only; no public internet exposure is intended.

No post-deploy sops key rotation needed — the host key is stable from first boot.

## Deployment Workflow

**Cold-install (bootstrap only):** `nix run '.#reinstall-homeserver' -- <target-ip>` uses `--no-substitute-on-destination`, preventing package substitution on an empty target. This is slower (builds closures on-destination) but required for fresh deployments with no existing closure store.

**Ongoing updates:** Use `deploy '.#homeserver'`, which substitutes pre-built closures and is orders of magnitude faster.

After initial hardware bootstrap, always use normal deployment tools for config updates.

## Architecture

- **Config**: `hosts/homeserver/default.nix` — enables `modules/nixos/profiles/observability/` as the full stack
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
