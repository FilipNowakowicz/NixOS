# Homeserver Security Invariants

## Goal

Encode the audit's expected production posture as enforced flake checks.

## Scope

- extend `lib/invariants.nix`
- extend `flake.nix` host checks for `homeserver`
- add unit coverage in `tests/lib/invariants.nix`

## Likely Files

- `lib/invariants.nix`
- `flake.nix`
- `tests/lib/invariants.nix`

## Tasks

- [ ] add reusable assertions for trusted users and firewall exposure
- [ ] add `homeserver` checks for sudo password requirement
- [ ] add `homeserver` checks for absence of globally open `22` and `443`
- [ ] add `homeserver` checks for allowed Tailscale-only exposure
- [ ] keep error messages specific enough to diagnose failed evals quickly
- [ ] add tests covering pass and fail cases

## Acceptance Criteria

- `flake check` fails if `homeserver` reintroduces passwordless sudo
- `flake check` fails if `homeserver` globally opens `22` or `443`
- `flake check` fails if `homeserver` trusts non-root Nix users
- tests exercise the new assertion helpers directly

## Validation

- `nix build '.#checks.x86_64-linux.invariants-homeserver'`
- `nix build '.#checks.x86_64-linux.tests-lib-invariants' || nix build '.#checks.x86_64-linux.lib-invariants-tests'`
- `nix flake check --no-build`

## Notes

- Coordinate with the access-posture PR; this branch should assume that PR lands first or stack on top of it.
