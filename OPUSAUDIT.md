1. Security — natural continuation

Your security profile is ~25 lines of sysctl + SSH. Intent >> reality. Natural path:

- Systemd hardening DSL (medium) — extract from lib/sandbox.nix into a proper module (services.hardened.<name> with ProtectSystem=strict, NoNewPrivileges, RestrictNamespaces, SystemCallFilter=@system-service, etc.). Apply to every service you ship. Becomes your first candidate for extraction as a shareable module (goal #2 in GOALS.md).
- Host introspection → LGTM (medium) — auditd + osquery or lynis timer → logs to Loki → dashboards. Pairs perfectly with the observability stack you already have. Proves the LGTM investment for something other than infra metrics.
- Pentesting learning loop — the security devShell exists. Pair with a microvm.nix-based purple-team target: spin up a deliberately-misconfigured VM to attack, with OSQuery/auditd feeding your real LGTM. This is how you get signal that hardening actually works.

2. Unexplored territory

Genuinely new capabilities, not extensions.

- Dev environment templates (quick each) — nix flake init -t templates for your common project types. nix-direnv across the board. Makes this flake the source of all your per-project shells, not just system config.
- microvm.nix (medium) — run multiple lightweight NixOS VMs from main without QEMU orchestration. Replaces much of scripts/vm.sh for fast-iteration workflows and enables the purple-team target above.
- Container image builds via dockerTools (medium) — produce OCI images for your services from the same module definitions; gives you a deploy path that isn't tied to nixos-anywhere.
- Tailscale ACLs as Nix (medium, depends on host registry) — generate acl.hujson from the registry. Single source of truth for who-can-reach-what.

1. GCP homeserver — unlocks the deferred pile

Your real-hardware homeserver is blocked, but homeserver-vm and homeserver modules are already decoupled from hardware. One move unlocks several deferred items:

- Build a GCE image from the existing homeserver config (medium) — nixos-generators -f gce, push to GCS, boot via Terraform/OpenTofu. Tailscale subnet router role. Proves the module-per-host pattern under a third substrate and gives you a real target for:
  - Automated deploy pipeline (deferred) — self-hosted runner as a service in the cloud VM.
  - Off-site B2 backups (deferred) — credentials live in sops, restic module already exists.
  - Local DNS / AdGuard (deferred) — Tailscale MagicDNS + AdGuard container/module on the GCE instance.
- Substantial only if you include IaC + CI deploy. Without that, it's medium.

2. Intent-vs-reality gaps (worth a line each)

- "Passwordless sudo for VMs only" — no test enforces this.
- "Reproducibility" — no flake update automation, no reproducibility-check in CI (nix build --rebuild twice and compare hashes).
- "Security hardening in progress" — 25 lines of profile vs. broad stated ambition.
- "Graceful failure handling" — main has zero monitoring.
- Alloy/Grafana use untyped strings for config — fragile in a repo that otherwise prizes type-safety.
