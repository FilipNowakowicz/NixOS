# Homeserver Goals

This is the implementation roadmap for `homeserver-gcp`.

Current baseline: GCP `e2-medium` in `us-central1`, reachable through
Tailscale only, running Vaultwarden, Nginx with Tailscale-issued TLS, the LGTM
observability stack, and Backblaze B2 restic backups. Provisioning is automated
through `scripts/deploy-gcp.sh`.

## Difficulty Scale

| Difficulty | Meaning                                                                                         |
| :--------- | :---------------------------------------------------------------------------------------------- |
| Easy       | Small Nix/service change; low migration risk.                                                   |
| Medium     | Several modules or external systems; needs careful validation.                                  |
| Hard       | Stateful migration, security-sensitive design, CI/deploy plumbing, or external API integration. |

## Recommended Order

| Order | Goal                                  | Difficulty | Status   | Why this order                                                                                      |
| :---- | :------------------------------------ | :--------- | :------- | :-------------------------------------------------------------------------------------------------- |
| 1     | Backup verification and restore drill | Medium     | Done     | Backups already run; prove they restore before adding more state.                                   |
| 2     | Live endpoint smoke tests             | Medium     | Done     | Gives a fast safety net for later changes to Nginx, Vaultwarden, Grafana, and ingest paths.         |
| 3     | LGTM alert tuning                     | Medium     | Done     | The stack is live; make it detect disk, service, and backup failures before expanding scope.        |
| 4     | Vaultwarden websocket notifications   | Easy       | Done     | Small user-facing improvement with limited blast radius.                                            |
| 5     | Disk layout decision                  | Medium     | Done     | Root-only layout is intentional; split storage only when a concrete retention or quota need exists. |
| 6     | GCE disk snapshots                    | Medium     | Done     | Daily 7-day provider-local boot disk snapshots are attached for fast rollback alongside restic.     |
| 7     | Local DNS and ad-blocking             | Medium     | Done     | First new service; depends on backup, smoke, alert, and disk posture being clear.                   |
| 8     | Secret rotation ritual                | Medium     | Deferred | Valuable once deploy/smoke paths can prove rotation did not break the server.                       |
| 9     | ACL drift detection                   | Medium     | Done     | GitHub Actions workflow compares generated ACL against live Tailscale API and alerts on drift.      |
| 10    | Vulnix/CVE dashboard                  | Medium     | Done     | Daily vulnix-scan timer, textfile metrics, CVE Scan dashboard, VulnixCveFound/ScanStale alerts.     |
| 11    | Automated deploy pipeline             | Hard       | Later    | High leverage, but design depends on runner placement, KVM needs, and smoke-test coverage.          |
| 12    | Tailscale-aware Grafana SSO           | Hard       | Later    | Removes a secret, but authentication mistakes can lock out observability.                           |
| 13    | Host introspection into LGTM          | Medium     | Done     | Daily lynis-audit timer, hardening index + warnings metrics, LynisScoreLow/ScanStale alerts.        |
| 14    | Typed Nginx/timer generators          | Medium     | Later    | Refactor after enough repeated service patterns exist.                                              |
| 15    | Service composition DSL               | Hard       | Deferred | Worth doing only after Vaultwarden plus at least one more service show the real abstraction shape.  |

## Goal Details

### 8. Secret Rotation Ritual

Make rotation repeatable before secrets age indefinitely.

Implementation:

- Document cadence per secret: Tailscale auth key, Grafana admin password, Grafana secret key, restic password, B2 credentials, and observability ingest credentials.
- Add a low-friction checklist for rotating each secret through sops and deploy.
- Surface days since last rotation in Grafana if the metadata can be represented cleanly.

Acceptance:

- Each secret has an owner, rotation trigger, and command path.
- Rotation does not require rediscovering deployment order from scratch.

### 11. Automated Deploy Pipeline

Automate deployment only after smoke tests are useful enough to catch bad
rollouts.

Recommended design: split responsibilities. Run lint, eval, and homeserver
builds on a lightweight always-on runner. Keep KVM-dependent VM tests on `main`
or another KVM-capable machine.

Implementation:

- Package a self-hosted GitHub Actions runner as a NixOS service.
- Decide whether the always-on runner lives on `homeserver-gcp` or a different host.
- Run smoke tests before deploy.
- Deploy `homeserver-gcp` first, verify, then deploy `main` if needed.

Acceptance:

- No deployment pushes directly to `main`.
- Failed validation blocks rollout.
- Runner secrets have a rotation/removal procedure.

### 12. Tailscale-Aware Grafana SSO

Replace Grafana local admin login with tailnet identity only after the proxy
and break-glass story is clear.

Implementation:

- Evaluate `tailscale serve` or an auth proxy that injects verified identity headers.
- Map allowed Tailscale identities to Grafana roles.
- Keep a documented emergency admin path until SSO has been proven.

Acceptance:

- Grafana access is tied to Tailscale identity.
- Removing the Grafana admin password does not remove break-glass access.

### 14. Typed Nginx/Timer Generators

Extend the existing typed generator approach where it reduces mistakes in
repeated service plumbing.

Implementation:

- Add typed Nginx location generation for proxy target, auth, and websocket settings.
- Add typed timer generation for schedule plus jitter.
- Convert only repeated patterns; do not generalize one-off service config.

Acceptance:

- Generated config is simpler to review than hand-written Nix.
- At least two services consume the generator before it is considered stable.

### 15. Service Composition DSL

Build this only after the server has enough services to justify the abstraction.

Implementation:

- Prototype around Vaultwarden and AdGuard, not around imaginary services.
- Wire hardening, observability, firewall, Nginx, and backup hooks from one typed service declaration.
- Keep escape hatches for service-specific systemd hardening and Nginx locations.

Acceptance:

- Adding a normal homeserver service requires fewer cross-cutting edits.
- The DSL does not hide security-sensitive exposure or backup decisions.

## Removed Or Deferred

These items were intentionally changed from the old roadmap:

- The self-hosted deploy pipeline moved later because useful smoke tests should exist before deployment automation.
- Broad service DSL work moved to deferred because premature abstraction would make the next service harder, not easier.
