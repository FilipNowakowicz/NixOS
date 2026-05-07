# homeserver-gcp Host

GCP-hosted headless server. Runs Vaultwarden, LGTM stack, Tailscale, and Nginx.
No LUKS or impermanence (GCP handles at-rest encryption; state persists on the GCE disk).

Status: **active** — deployed on GCP, accessible via Tailscale.

## Services

- **Vaultwarden** — `127.0.0.1:8222`, proxied via Nginx over HTTPS
- **LGTM stack** — Grafana (sub-path `/grafana/`), Loki, Mimir, Tempo (full observability)
- **Nginx** — reverse proxy, TLS via Tailscale cert
- **SSH** — firewall exposure limited to `tailscale0`
- **Tailscale** — auth key from sops secret `tailscale_auth_key`
- **Restic/B2** — off-site backups to Backblaze B2 (`/var/lib/vaultwarden`, `/var/lib/grafana`)

## Architecture

- **No LUKS** — GCP provides at-rest disk encryption automatically
- **No impermanence** — service state persists at `/var/lib/...` on the stateful GCE disk
- **systemd-boot** — UEFI bootloader (see `hardware-configuration.nix`)
- **50 GB boot disk** — partitioned by `disko.nix` (512 MB ESP + ext4 root taking the rest)

## Sops Bootstrap

Pre-baked host SSH key is committed encrypted to the repo.

- Private key: `hosts/homeserver-gcp/secrets/ssh_host_ed25519_key.enc`
- Public key: `hosts/homeserver-gcp/secrets/ssh_host_ed25519_key.pub.enc`
- Age identity: `&homeserver_gcp_host` in `.sops.yaml`

`nix build '.#checks.x86_64-linux.homeserver-gcp-sops-bootstrap'` verifies both files are present.

The pre-baked key is injected into the VM **automatically** on first boot:

1. `scripts/deploy-gcp.sh` decrypts the key and passes it to OpenTofu as `ssh_host_key_b64`.
2. OpenTofu (`infra/main.tf`) attaches it as the `ssh-host-key-b64` GCE instance metadata attribute.
3. The `injectGceSshHostKey` activation script in `default.nix` reads that metadata over the GCE metadata server before sops-nix runs and installs it at `/etc/ssh/ssh_host_ed25519_key`.

No manual key injection step is needed.

## Provisioning

Provisioning is end-to-end automated via `scripts/deploy-gcp.sh`:

```bash
nix develop                          # provides sops, opentofu, nixos-anywhere, gcloud
bash scripts/deploy-gcp.sh           # plan + apply (interactive)
bash scripts/deploy-gcp.sh -auto-approve
bash scripts/deploy-gcp.sh -destroy  # tear down bootstrap infra
```

The script:

1. Decrypts the pre-baked SSH host key.
2. Runs `tofu apply` to create the GCE VM (with the host key in metadata + the operator's bootstrap pubkey).
3. Waits for SSH to come up.
4. Runs `nixos-anywhere --flake '.#homeserver-gcp'` to install NixOS over the bootstrap image.

Before the first run, copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars` and fill in the GCP project ID.

## First Deploy Checklist

When provisioning from scratch:

1. **Fill in real secrets** — `sops hosts/homeserver-gcp/secrets/secrets.yaml`, set:
   - `tailscale_auth_key` — Tailscale admin → Settings → Keys → reusable + ephemeral
   - `user_password` — bcrypt hash: `mkpasswd -m bcrypt`
   - `grafana_admin_password`, `grafana_secret_key`, `observability_ingest_htpasswd`
   - `restic_password`, `b2_credentials` (env-file format: `B2_ACCOUNT_ID=…` / `B2_ACCOUNT_KEY=…`)

2. **Provision the VM + install NixOS** — `bash scripts/deploy-gcp.sh` (see above).

3. **Wait ~60s for first boot** — sops decrypts secrets, Tailscale joins the tailnet.

4. **Confirm reachability** — `tailscale status | grep homeserver-gcp`.

5. **Remove bootstrap metadata** — run the command printed by `tofu output ssh_host_key_removal_cmd` to scrub the host key, bootstrap pubkey, and startup script from instance metadata.

6. **Create Vaultwarden account** — temporarily set `SIGNUPS_ALLOWED = true`, deploy, sign up, set back to `false`, redeploy.

## Ongoing Updates

```bash
deploy '.#homeserver-gcp'
```

## Gotchas

- **sops fails on first boot if host key wasn't injected** — Tailscale won't join, SSH won't
  work over Tailscale. Recover via GCE serial console or `gcloud compute ssh` (project SSH keys
  bypass tailnet-only firewall during recovery).
- **TLS cert is not ACME** — `tailscale-cert.service` fetches it via `tailscale cert`; nginx
  depends on that service via `requires=` so it doesn't start without a cert.
- **Access is tailnet-only** — `tailscale0` is the only interface that permits inbound SSH/HTTPS.
- **Disk is stateful** — no impermanence. Data survives reboots naturally.
- **Off-site backup via B2** — `services.restic.backups.b2` runs daily at 03:00 with its own
  prune policy (7d/4w/6m). The shared `modules/nixos/profiles/backup.nix` retention class is
  not currently consumed by this host.
