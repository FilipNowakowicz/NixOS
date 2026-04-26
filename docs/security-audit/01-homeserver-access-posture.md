# Homeserver Access Posture

## Goal

Remove development-grade access posture from `homeserver` and make remote access tailnet-only.

## Scope

- split `modules/nixos/profiles/machine-common.nix` into production-safe and dev/VM profiles
- stop importing the permissive profile from `hosts/homeserver/default.nix`
- require sudo password on `homeserver`
- remove non-root trusted Nix users on `homeserver`
- restrict SSH and HTTPS firewall exposure to `tailscale0`

## Likely Files

- `modules/nixos/profiles/machine-common.nix`
- `modules/nixos/profiles/*.nix`
- `hosts/homeserver/default.nix`
- `hosts/homeserver/CLAUDE.md`
- `docs/security.md`

## Tasks

- [x] identify which settings in `machine-common.nix` are VM/dev-only
- [x] create a production-safe split that preserves existing behavior on `vm` and `homeserver-vm`
- [x] update `homeserver` imports and explicit SSH/sudo/trusted-users settings
- [x] replace global `allowedTCPPorts = [ 443 ]` with `tailscale0`-scoped rules
- [x] decide whether `homeserver` SSH remains enabled for deploy/break-glass and encode that explicitly
- [x] update docs to match the new posture

## Acceptance Criteria

- `homeserver` no longer inherits passwordless sudo
- `homeserver` no longer trusts `"user"` for Nix builds
- `homeserver` does not globally expose TCP `22` or `443`
- `vm` and `homeserver-vm` retain intended dev behavior

## Validation

- `nix build '.#checks.x86_64-linux.invariants-homeserver'`
- `nix build '.#checks.x86_64-linux.invariants-vm'`
- `nix build '.#checks.x86_64-linux.invariants-homeserver-vm'`

## Notes

- This PR should not add the invariant framework changes itself unless needed to keep existing checks passing.
