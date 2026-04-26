# Tailscale ACL Least Privilege

## Goal

Replace broad `tag:server:*` access with explicit host:port policy that matches the intended service perimeter.

## Scope

- refine `lib/acl.nix`
- add tests or assertions for the generated ACL artifact
- preserve admin break-glass access where intended

## Likely Files

- `lib/acl.nix`
- `flake.nix`
- tests covering generated ACL output
- `docs/security.md`

## Tasks

- [ ] inventory intended cross-tag access paths
- [ ] replace wildcard server access with explicit destinations
- [ ] preserve required admin access intentionally, not accidentally
- [ ] add checks that fail on reintroduction of wildcard server exposure

## Acceptance Criteria

- workstation-to-server access is limited to explicitly approved ports
- ACL generation remains deterministic from the host registry
- tests cover the expected generated policy

## Validation

- build the ACL artifact
- run ACL-focused tests/assertions
- inspect rendered JSON for host:port specificity

## Notes

- Keep this aligned with the host-level firewall posture; do not assume ACLs are the only boundary.
