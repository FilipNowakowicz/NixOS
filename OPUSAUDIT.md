1. Unexplored territory

- Container image builds via dockerTools (medium) — produce OCI images for your services from the same module definitions; gives you a deploy path that isn't tied to nixos-anywhere.
- Tailscale ACLs as Nix (medium, depends on host registry) — generate acl.hujson from the registry. Single source of truth for who-can-reach-what.

2. GCP homeserver — unlocks the deferred pile

Your real-hardware homeserver is blocked, but homeserver-vm and homeserver modules are already decoupled from hardware. One move unlocks several deferred items:

- Build a GCE image from the existing homeserver config (medium) — nixos-generators -f gce, push to GCS, boot via Terraform/OpenTofu. Tailscale subnet router role. Proves the module-per-host pattern under a third substrate and gives you a real target for:
  - Automated deploy pipeline (deferred) — self-hosted runner as a service in the cloud VM.
  - Off-site B2 backups (deferred) — credentials live in sops, restic module already exists.
  - Local DNS / AdGuard (deferred) — Tailscale MagicDNS + AdGuard container/module on the GCE instance.
- Substantial only if you include IaC + CI deploy. Without that, it's medium.
