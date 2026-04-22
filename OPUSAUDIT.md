1. Security — natural continuation

- Pentesting learning loop — the security devShell exists. Pair with a microvm.nix-based purple-team target: spin up a deliberately-misconfigured VM to attack, with OSQuery/auditd feeding your real LGTM. This is how you get signal that hardening actually works.

2. Unexplored territory

- Dev environment templates (quick each) — nix flake init -t templates for your common project types. nix-direnv across the board. Makes this flake the source of all your per-project shells, not just system config.
- Container image builds via dockerTools (medium) — produce OCI images for your services from the same module definitions; gives you a deploy path that isn't tied to nixos-anywhere.
- Tailscale ACLs as Nix (medium, depends on host registry) — generate acl.hujson from the registry. Single source of truth for who-can-reach-what.

3. GCP homeserver — unlocks the deferred pile

Your real-hardware homeserver is blocked, but homeserver-vm and homeserver modules are already decoupled from hardware. One move unlocks several deferred items:

- Build a GCE image from the existing homeserver config (medium) — nixos-generators -f gce, push to GCS, boot via Terraform/OpenTofu. Tailscale subnet router role. Proves the module-per-host pattern under a third substrate and gives you a real target for:
  - Automated deploy pipeline (deferred) — self-hosted runner as a service in the cloud VM.
  - Off-site B2 backups (deferred) — credentials live in sops, restic module already exists.
  - Local DNS / AdGuard (deferred) — Tailscale MagicDNS + AdGuard container/module on the GCE instance.
- Substantial only if you include IaC + CI deploy. Without that, it's medium.
