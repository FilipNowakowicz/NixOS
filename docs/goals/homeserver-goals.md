# Homeserver Goals

Implementation roadmap for `homeserver-gcp`. The reliability work that motivated
this document is complete (see below); this tracks any future homeserver goals.

Current baseline: GCP `e2-medium` in `europe-west2` (`europe-west2-a` zone by
default), reachable through Tailscale only, running Vaultwarden, AdGuard Home,
Nginx with Tailscale-issued TLS, the LGTM observability stack, and Backblaze B2
restic backups (with weekly integrity check + daily restore canary). Daily GCE
boot-disk snapshots and a public-SSH edge deny are managed in `infra/`. The
instance is a Shielded VM (vTPM + integrity monitoring) and an off-box
dead-man's-switch covers total-host-death liveness. Provisioning is automated
through `scripts/deploy-gcp.sh`.

Completed milestones live in the durable docs:

- `README.md` — service surface, dashboards, generated inventory.
- `docs/operations.md` — smoke tests, snapshots, drift guard, validation workflows.
- `docs/security.md` — exposure, Shielded VM, ACL drift detection.
- `docs/backup-validation.md` — restore canary (incl. Vaultwarden DB integrity).
- `docs/restore-drill.md` — backup recovery procedure.
- `hosts/homeserver-gcp/CLAUDE.md` — host-specific operating notes (heartbeat, canary).

## Framing

The host self-monitors well, but **every alerting component (Mimir ruler,
Alertmanager, the ntfy webhook) runs on the host it watches** — if the VM dies,
nothing fires. The provider-native checklist (Cloud Monitoring / Logging /
Secret Manager) was the wrong lens: a tailnet-only host has no public endpoint
for an external uptime probe, and there is no real metadata-secret reliance to
migrate. The reliability work was therefore reshaped around the one genuine gap —
**off-box liveness** — plus small, high-value hardening and verification, all
now shipped (see below).

## Active Goals

None. The reliability gap that motivated this document is closed; the four
shipped items moved to the durable docs and are summarised below. New homeserver
work, when it appears, goes here.

## Completed (now in durable docs)

All four deployed, verified, and merged (#77, #78). Recorded here only as a
pointer to where each now lives.

| Goal                                      | Lives in                                                                 |
| :---------------------------------------- | :----------------------------------------------------------------------- |
| Off-box dead-man's-switch                 | `hosts/homeserver-gcp/heartbeat.nix`; `hosts/homeserver-gcp/CLAUDE.md`   |
| Vaultwarden DR canary extension           | `hosts/homeserver-gcp/backups.nix`; `docs/backup-validation.md`          |
| Shielded VM (vTPM + integrity monitoring) | `infra/main.tf`; `docs/security.md` (§ Shielded VM)                      |
| Terraform drift guard                     | `scripts/validate.sh tf-drift`; `docs/operations.md` (§ Terraform Drift) |

## Dropped / Parked

- **Billing budgets** — handled via in-app GCP billing tracking; not a repo goal.
- **Secret Manager** — dropped. No metadata-secret reliance exists (the only
  metadata value is a _public_ bootstrap key); sops covers everything real.
  Reopen only if a concrete provider-managed-secret need appears.
- **Cloud Logging** — parked, narrowed. The serial console is already enabled
  and live-reachable via `gcloud`; the only incremental value is _historical_
  serial/audit capture for post-crash forensics. Revisit if a real post-mortem
  ever needs logs from a VM that was unreachable at the time.

## Notes

- `Cloud DNS`, `Cloud KMS`, and the `Service composition DSL` live in
  [`roadmap.md`](roadmap.md) (DSL canonical there; KMS/DNS parked as speculative
  for a tailnet-only host).
- `Automated deploy pipeline` and `Secret rotation ritual` also live in
  [`roadmap.md`](roadmap.md) and are not active homeserver priorities.
- **AdGuard is a fleet-wide DNS SPOF.** If the host dies, tailnet clients using
  it as DNS lose resolution (recovery in `hosts/homeserver-gcp/CLAUDE.md`). This
  reinforces the off-box heartbeat: you want to learn the host is down from
  something that is _not_ behind that DNS.
