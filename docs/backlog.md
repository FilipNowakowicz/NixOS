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
