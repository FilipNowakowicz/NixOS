# Operations

This document is the runbook for day-to-day work in this flake. Keep the
README high-level; put command-heavy procedures here.

## Canonical Sources

- `README.md` - project overview, host inventory, feature map.
- `CLAUDE.md` - agent/operator preferences and validation shortcuts.
- `docs/architecture.md` - structural rules and module boundaries.
- `docs/security.md` - secrets, network exposure, and hardening model.
- `docs/restore-drill.md` - quarterly manual restore procedure for the B2 restic repository.

## Deployment Matrix

| Target           | Status           | Command                                  | Notes                                                          |
| :--------------- | :--------------- | :--------------------------------------- | :------------------------------------------------------------- |
| `main`           | Active           | `nh os switch --hostname main .`         | Primary workstation.                                           |
| `homeserver-gcp` | Active           | `deploy '.#homeserver-gcp'`              | GCP homeserver; see `scripts/deploy-gcp.sh`.                   |
| `vm`             | Legacy Supported | `deploy '.#vm'`                          | Requires a QEMU VM created with `nix run '.#vm' -- create vm`. |
| `user@wsl`       | Active           | `home-manager switch --flake .#user@wsl` | Portable Home Manager profile for WSL.                         |

## QEMU VM

`scripts/vm.sh` and `nix run '.#vm'` are legacy-supported for hardware-style
testing: impermanence, bootloader behavior, and LUKS workflows. They are not
the `homeserver-vm` path.

```bash
nix run '.#vm' -- create vm
nix run '.#vm' -- start vm
nix run '.#vm' -- ssh vm
nix run '.#vm' -- stop vm
nix run '.#vm' -- reinstall vm
nix run '.#vm' -- destroy vm
```

QEMU VM metadata comes from `lib/hosts.nix`; entries need `sshPort` and
`diskSize` to appear in the VM registry.

## Homeserver GCE Snapshots

`infra/main.tf` attaches a daily GCE snapshot schedule to the
`homeserver-gcp` boot disk. These snapshots are provider-local rollback points
stored in Google Cloud snapshot storage, in `snapshot_storage_locations` when
set or in `var.region` by default. The default retention is 7 daily snapshots.

Use GCE snapshots for fast VM-shaped rollback after bad deploys, disk mistakes,
or package/config migrations. Use restic/B2 for durable application recovery,
off-site recovery, and point restores of `/var/lib/vaultwarden` or
`/var/lib/grafana`.

Inspect available scheduled snapshots:

```bash
gcloud compute snapshots list \
  --filter='labels.host=homeserver-gcp AND labels.purpose=fast-rollback' \
  --sort-by='~creationTimestamp'
```

Create a temporary disk from a snapshot for inspection or file extraction:

```bash
SNAPSHOT=<snapshot-name>
gcloud compute disks create homeserver-gcp-restore-inspect \
  --zone=europe-west2-a \
  --source-snapshot="$SNAPSHOT" \
  --type=pd-ssd
```

Attach that disk to a temporary recovery VM or to `homeserver-gcp` while it is
stopped, mount it read-only, and copy out the needed files. Delete the
inspection disk after recovery.

For full rollback, prefer creating a replacement VM or replacement boot disk
from the snapshot, then redeploying the NixOS configuration once the system is
reachable. This avoids treating provider-local snapshots as the authoritative
long-term backup and keeps Terraform/OpenTofu state drift visible.

## Homeserver Smoke Tests

`bash scripts/validate.sh smoke-homeserver-gcp` builds the booted NixOS test for
the live homeserver routing surface. The test checks:

- `/` reaches Vaultwarden through Nginx.
- `/grafana/` works as a sub-path deployment.
- `/obs/loki/`, `/obs/mimir/`, and `/obs/otlp/` enforce the expected auth boundary.

Use this before deploy work that touches `hosts/homeserver-gcp/` or the
observability ingress path.

## Tailscale ACL Drift

The generated ACL artifact is also checked against the live tailnet policy by
`.github/workflows/tailscale-acl-drift.yml`, which runs
`bash scripts/check-tailscale-acl-drift.sh`.

Run it locally when changing `lib/acl.nix` or registry-owned Tailscale metadata:

```bash
bash scripts/check-tailscale-acl-drift.sh
```

## Validation

Use the narrowest check that covers the files changed.

```bash
bash scripts/validate.sh flake-eval
bash scripts/validate.sh light
bash scripts/validate.sh host main-ci
bash scripts/validate.sh host vm-ci
bash scripts/validate.sh host homeserver-gcp
bash scripts/validate.sh hosts
bash scripts/validate.sh smoke-vm
bash scripts/validate.sh profile-tests
bash scripts/validate.sh heavy
bash scripts/validate.sh cve-reports
```

Rules of thumb:

- Shared flake, library, or global module changes: run `light` and affected host builds; use `hosts` when impact is broad.
- Desktop profile/Home Manager changes: build `main-ci` and `vm-ci`.
- Server profile/GCP changes: build `homeserver-gcp`.
- Docs changes: run `bash scripts/validate.sh docs`; CI runs this even for docs-only PRs.
- NixOS test changes: run the relevant smoke/profile test if KVM is available.

## Formatting And Hooks

```bash
nix fmt
nix fmt -- --fail-on-change
pre-commit run --all-files
statix check .
deadnix .
```

`nix develop` installs a `commit-msg` hook in the shared git hooks directory
that removes `Co-authored-by:` trailers.
