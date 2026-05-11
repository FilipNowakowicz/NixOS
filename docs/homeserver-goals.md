# Homeserver Goals

This is the remaining implementation roadmap for `homeserver-gcp`.

Current baseline: GCP `e2-medium` in `us-central1`, reachable through
Tailscale only, running Vaultwarden, Nginx with Tailscale-issued TLS, the LGTM
observability stack, and Backblaze B2 restic backups. Provisioning is automated
through `scripts/deploy-gcp.sh`.

Completed milestones have been folded into the durable docs:

- `README.md` for the current service surface, observability dashboards, and generated inventory.
- `docs/operations.md` for smoke tests, snapshots, and validation workflows.
- `docs/security.md` for exposure and ACL drift detection.
- `docs/restore-drill.md` for backup recovery procedure.
- `hosts/homeserver-gcp/CLAUDE.md` for host-specific operating notes.

## Difficulty Scale

| Difficulty | Meaning                                                                                         |
| :--------- | :---------------------------------------------------------------------------------------------- |
| Easy       | Small Nix/service change; low migration risk.                                                   |
| Medium     | Several modules or external systems; needs careful validation.                                  |
| Hard       | Stateful migration, security-sensitive design, CI/deploy plumbing, or external API integration. |

## Recommended Order

| Order | Goal                         | Difficulty | Status   | Why this order                                                                                     |
| :---- | :--------------------------- | :--------- | :------- | :------------------------------------------------------------------------------------------------- |
| 1     | Tailscale-aware Grafana SSO  | Hard       | Done     | Completed: Grafana access is now tied to Tailscale identity with a documented break-glass path.    |
| 2     | Typed Nginx/timer generators | Medium     | Done     | Completed as narrow helpers for repeated proxy locations and scheduled maintenance timers.         |
| 3     | Service composition DSL      | Hard       | Deferred | Worth doing only after Vaultwarden plus at least one more service show the real abstraction shape. |

## Goal Details

### 1. Tailscale-Aware Grafana SSO

Replace Grafana local admin login with tailnet identity only after the proxy
and break-glass story is clear.

Implementation:

- Evaluate `tailscale serve` or an auth proxy that injects verified identity headers.
- Map allowed Tailscale identities to Grafana roles.
- Keep a documented emergency admin path until SSO has been proven.

Acceptance:

- Grafana access is tied to Tailscale identity.
- Removing the Grafana admin password does not remove break-glass access.

Status:

- Done on `homeserver-gcp`: nginx now gates `/grafana/` through a local Tailscale-aware auth helper, Grafana trusts auth-proxy headers from localhost, and the break-glass path remains local admin access over SSH port-forwarding.

### 2. Typed Nginx/Timer Generators

Extend the existing typed generator approach where it reduces mistakes in
repeated service plumbing.

Implementation:

- Add typed Nginx location generation for proxy target, auth, and websocket settings.
- Add typed timer generation for schedule plus jitter.
- Convert only repeated patterns; do not generalize one-off service config.

Acceptance:

- Generated config is simpler to review than hand-written Nix.
- At least two services consume the generator before it is considered stable.

Status:

- Done on `homeserver-gcp`: `lib/generators.nix` now exposes a narrow nginx proxy-location helper for `proxyPass`, websocket, basic-auth, and escape-hatch config, plus a systemd timer helper for schedule and jitter. Vaultwarden, Grafana, observability ingest routes, and repeated maintenance timers consume it; one-off aliases and auth subrequest internals remain hand-written.

### 3. Service Composition DSL

Build this only after the server has enough services to justify the abstraction.

Implementation:

- Prototype around Vaultwarden and AdGuard, not around imaginary services.
- Wire hardening, observability, firewall, Nginx, and backup hooks from one typed service declaration.
- Keep escape hatches for service-specific systemd hardening and Nginx locations.

Acceptance:

- Adding a normal homeserver service requires fewer cross-cutting edits.
- The DSL does not hide security-sensitive exposure or backup decisions.

## Notes

- `Automated deploy pipeline` and `Secret rotation ritual` have been moved to `docs/backlog.md` and are no longer active homeserver priorities.
- Broad service DSL work stays deferred until there are enough repeated service patterns to justify the abstraction.
