# Reinstall Target Verification

## Goal

Prevent `reinstall-homeserver` from sending the stable host identity to an unauthenticated target.

## Scope

- harden `scripts/reinstall-homeserver.sh`
- require explicit host-key verification or a supplied `known_hosts` entry before install
- document the operator workflow

## Likely Files

- `scripts/reinstall-homeserver.sh`
- `flake.nix` if app wiring changes
- `docs/operations.md`
- `hosts/installer/CLAUDE.md` or related docs if helpful

## Tasks

- [ ] decide the operator interface: expected fingerprint, known-hosts file, or both
- [ ] fail closed when the installer host key is absent or changed
- [ ] pass the verified SSH options through to `nixos-anywhere`
- [ ] document the bootstrap workflow clearly

## Acceptance Criteria

- reinstall flow does not default to blind TOFU for the target
- the script emits actionable errors on mismatch or missing trust material
- the documented operator flow is explicit and repeatable

## Validation

- shellcheck on the script
- dry-run/evaluated command path review
- any existing reinstall-related checks still pass

## Notes

- Prefer a design that works with ephemeral installer images without weakening verification.
