# Backlog

Deferred work that is intentionally not in `docs/goals.md`.

## Cross-System Check Strategy

Status: postponed until the first non-`x86_64-linux` host is planned or added.

Why postponed:

- The current fleet appears to be `x86_64-linux` only.
- The immediate structural change is per-host `system` metadata in `lib/hosts.nix`.
- Broadening checks now would add CI and tooling complexity before there is a concrete second architecture to validate.

Depends on:

- Per-host system declarations for hosts, so architecture selection comes from host metadata instead of a single global flake default.

Scope when revisited:

- `nix flake check --all-systems`
- `aarch64-linux` evaluation readiness
- Gating or refactoring x86-specific VM and test tooling

## Homeserver Parked Ideas

Status: not active priorities right now; revisit if manual deploys or secret hygiene become real pain points.

### Automated Deploy Pipeline

Why parked:

- Manual deploy flow is currently acceptable.
- The repo already has validation and smoke-test entrypoints without requiring GitHub Actions automation.
- Runner placement and KVM split still add operational complexity.

Scope when revisited:

- Self-hosted GitHub Actions runner as a NixOS service
- Validation and smoke-test gating before deploy
- Ordered rollout for `homeserver-gcp` and then `main`

### Secret Rotation Ritual

Why parked:

- Rotation is useful but largely procedural and only partly automatable.
- The current setup does not justify prioritizing this over active service and auth work.

Scope when revisited:

- Secret inventory with owner, trigger, and command path
- Rotation checklist through `sops` and deploy
- Optional Grafana visibility for secret age metadata
