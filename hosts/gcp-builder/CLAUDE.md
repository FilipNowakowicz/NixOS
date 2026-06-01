# gcp-builder Host

On-demand GCP Nix remote builder. Normally **powered off**; `main` starts it
transparently for heavy builds and it powers itself off when idle. Disposable:
no persistent service state, no sops secrets, no backup.

Status: **active** (provisioned once, then start/stop on demand).

## What it is / isn't

- **Is:** a headless `n2-standard-4` (nested virtualization enabled) that builds
  Nix closures and runs the KVM-backed nixos test suite offloaded from `main`.
- **Isn't:** a service host. No Vaultwarden/AdGuard/LGTM/nginx, no backups, no
  Home Manager, no sops. Losing it costs nothing but provisioning time.

## How `main` uses it

- `main` carries a dedicated build key (`root`'s nix-daemon → trusted `user@`
  here): private half is sops-encrypted at
  `hosts/main/secrets/gcp_builder_build_key.enc`, public half is authorized in
  `hosts/gcp-builder/default.nix`.
- `nix.buildMachines` is intentionally **not** set on `main` — that would make
  every ordinary `rebuild` pay an SSH-connect timeout while the builder is off.
  Instead `scripts/validate.sh` (`host`/`hosts`/`heavy`/`profile-test(s)`/
  `smoke-*`) calls `ensure_builder`: it `gcloud`-starts the VM, waits for SSH
  over Tailscale, and passes `--builders` for that one invocation.
- Knobs: `USE_BUILDER=0` disables offload; `BUILDER_ZONE`, `BUILDER_FQDN`,
  `BUILDER_MAXJOBS` override defaults. Offload is a silent no-op (local build)
  when `gcloud` is absent or the build key isn't present (CI, fresh clones).
- **Prerequisite:** `gcloud` on `main` must be authenticated and have the
  builder's project as its active config (`gcloud config set project <id>`).

## Idle auto-shutdown

`builder-idle-shutdown.timer` (in `default.nix`) checks every 5 min and powers
the box off after 20 min with no established port-22 connection (no session, no
in-flight distributed build). The stamp lives in `/run`, so a fresh boot gets a
full grace window before the first check.

## Provisioning (operator-only, one time)

The builder is sops-free, so there is no pre-baked host-key injection like the
homeserver — `nixos-anywhere` installs straight onto the bootstrap image.

1. **tfvars** — ensure `infra/terraform.tfvars` has `gcp_project` and
   `bootstrap_ssh_public_key` (shared with the homeserver flow).

2. **Create the VM** — `cd infra && tofu plan && tofu apply`. Review the plan:
   the disk-type/`desired_status` pins mean the existing homeserver instance must
   show **no** changes; only `gcp-builder` resources should be created.

3. **Temporary SSH path** — the network-wide `deny_public_ssh` rule blocks public
   TCP/22, so open a scoped, higher-priority hole to the builder for install:

   ```bash
   gcloud compute firewall-rules create gcp-builder-provision-ssh \
     --network=default --direction=INGRESS --action=ALLOW \
     --rules=tcp:22 --target-tags=gcp-builder --priority=400 \
     --source-ranges="$(curl -fsS ifconfig.me)/32"
   ```

4. **Install NixOS** — over the bootstrap account (NOPASSWD sudo):

   ```bash
   IP=$(cd infra && tofu output -raw builder_external_ip)
   nix run github:nix-community/nixos-anywhere -- --flake .#gcp-builder \
     --target-host "bootstrap@$IP"
   ```

5. **Join the tailnet** — after reboot, SSH in as `user` (personal key, still via
   the temp rule) and bring Tailscale up tagged as a server:

   ```bash
   ssh "user@$IP" sudo tailscale up --advertise-tags=tag:server
   ```

   Follow the printed auth URL. (`acceptFrom`/tag come from `lib/hosts.nix`;
   regenerate and push the tailnet ACL from the `tailscale-acl` package so the
   new node's tag is recognized.)

6. **Verify + lock down** — `tailscale status | grep gcp-builder`, then remove the
   temporary hole:

   ```bash
   gcloud compute firewall-rules delete gcp-builder-provision-ssh --quiet
   ```

7. **Deploy the wiring to `main`** — `nh os switch --hostname main .` so the build
   key and ssh policy land, then confirm an offloaded build:

   ```bash
   gcloud compute instances stop gcp-builder --zone "$ZONE"   # prove cold start
   bash scripts/validate.sh host homeserver-gcp
   # expect: "remote builder: gcp-builder ready; offloading builds"
   # and nix logging: building '…' on 'ssh-ng://user@gcp-builder.…'
   ```

## Build key rotation

The build link key is low-stakes and rotatable:

1. `ssh-keygen -t ed25519 -f /tmp/k -N "" -C nix-remote-build-main-to-gcp-builder`
2. Encrypt the private half (recipients picked from `.sops.yaml`):
   `sops -e --input-type binary --output-type binary --filename-override \
hosts/main/secrets/gcp_builder_build_key.enc /tmp/k > hosts/main/secrets/gcp_builder_build_key.enc`
3. Replace the public key in `hosts/gcp-builder/default.nix`, `shred -u /tmp/k`.
4. Redeploy `main` and `gcp-builder`.

## Gotchas

- **Reprovisioning changes the SSH host key.** `main` uses `accept-new` for the
  builder, so a changed key is rejected until the stale `known_hosts` entry is
  cleared — reboot `main` (its `/root` is ephemeral) or remove the entry.
- **nested virtualization is required** for the KVM test suite — keep the machine
  type in the `n2`/`n2d`/`c3` families; `e2` cannot run booted nixos tests.
- **Not a spot instance** — a preemptible reclaim would kill long `heavy` runs.
  Power state is start/stop only; never let Terraform manage `desired_status`.
- **No console password** — recover a wedged builder by reprovisioning, not via
  serial console.
