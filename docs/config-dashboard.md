# Config Dashboard Plan

This document defines the next iteration of the local config dashboard built by
`nix build '.#inventory'`.

The current page is a solid host inventory, but it does not yet connect
inventory state, active goals, and operator actions into one surface. The next
version should feel like an operator console for this flake rather than a
static host list.

## Goals

- Keep the dashboard generated from flake evaluation with no external service dependency.
- Separate manual roadmap items from computed configuration findings.
- Make current work visible without turning the page into a prose-heavy notes dump.
- Keep the page useful for day-to-day operation, not just repo archaeology.

## Non-Goals

- Do not turn the dashboard into a full task tracker.
- Do not depend on Grafana or the observability stack to render the local
  inventory page.
- Do not parse free-form Markdown aggressively when a small structured Nix data
  source is clearer.

## Design Direction

The page should have two distinct kinds of information:

1. Manual goals
   These are human-curated roadmap items such as "GCP homeserver" or
   "Automated deploy pipeline".
2. Computed attention items
   These are derived from live config, such as security gaps, missing backup
   coverage, or hosts missing an expected profile.

Those two categories should be rendered next to each other, but they should not
share one undifferentiated "Goals" box.

## Target Layout

From top to bottom:

1. Summary strip
   Keep the existing fleet summary and add goal counts by status.
2. Operator row
   Left: goals board.
   Right: attention panel derived from inventory data.
3. Fleet inventory
   Keep the existing host cards and filters.
4. Footer
   Keep build provenance and host list.

## Goals Board

The new goals section should replace the current vague roadmap idea with a
compact board split by status:

- `Now`
  Active work worth looking at this week.
- `Blocked`
  Work waiting on hardware, credentials, or another milestone.
- `Next`
  Important follow-on work once active blockers are cleared.
- `Later`
  Useful future work that should remain visible but not clutter the active set.

Each goal card should show:

- title
- short summary
- area (`homeserver`, `deploy`, `backup`, `observability`, `security`, `platform`)
- priority (`p1`, `p2`, `p3`)
- related hosts
- blockers, if any
- unlocks, if any
- doc links, if any

## Attention Panel

The dashboard should add a computed panel for items that deserve operator
attention right now. This is separate from roadmap planning.

Initial attention checks:

- host has SSH enabled without fail2ban
- host has SSH enabled without firewall
- desktop host without USBGuard
- backup-critical host without an explicit backup signal in metadata
- deployable host without observability client

This list should stay intentionally short. The signal matters more than breadth.

## Structured Goals Data

Introduce a small machine-readable source of truth, preferably `lib/goals.nix`.

Suggested shape:

```nix
[
  {
    id = "gcp-homeserver";
    title = "GCP homeserver";
    status = "now";
    priority = "p1";
    area = "homeserver";
    summary = "Boot the existing homeserver config on GCE to unblock downstream work.";
    hosts = [ "homeserver" ];
    blockedBy = [ ];
    unlocks = [ "deploy-pipeline" "b2-backups" "adguard" ];
    docs = [ "hosts/homeserver/CLAUDE.md" ];
  }
]
```

This should stay deliberately small. The goal is to support rendering and
filtering, not to model every project-management field imaginable.

`docs/goals.md` remains the canonical human-facing roadmap summary, while
`lib/goals.nix` becomes the canonical render source for the dashboard.

## Wave 1

Wave 1 is the first implementation pass and should ship the redesign rather
than every eventual feature.

### Scope

- add structured goals data
- redesign the dashboard to include a goals board
- add a computed attention panel
- add filters for goal area and status
- keep the existing host inventory intact
- link the goals back to canonical docs

### Files to Touch

- `lib/goals.nix`
- `packages/inventory.nix`
- `flake.nix`
- `docs/goals.md`
- optionally `README.md` if the docs map should mention the dashboard plan

### Implementation Sequence

1. Create `lib/goals.nix` with a small set of current goals and future waves.
2. Pass goals data into `packages/inventory.nix` from `flake.nix`, or import it
   directly there if that stays cleaner.
3. Extend the generated HTML in `packages/inventory.nix` with:
   - a goals summary
   - a goals board
   - an attention panel
4. Keep the current host grid below the new operator row.
5. Add lightweight CSS and client-side rendering for goal cards and filters.
6. Update `docs/goals.md` so the prose view and the structured data describe the
   same priorities.

### Acceptance Criteria

- `nix build '.#inventory'` renders goals and inventory in one page.
- goals are not hard-coded in HTML string fragments
- active vs blocked vs future work is visually obvious
- computed findings are displayed separately from human roadmap items
- the existing host cards still render correctly

## Wave 2

Wave 2 should deepen operator usefulness without changing the basic dashboard
model.

Status: implemented in the dashboard as validation commands, related host and
service chips, dependency context, and host/service filters.

### Scope

- validation commands per host or goal
- related services and related hosts chips on goal cards
- dependency and unlock context in the UI
- priority-first sorting
- optional host-to-goal filters

### Candidate Features

- `Validate` section with commands such as `nix flake check`, smoke tests, and
  deployment commands
- `Depends on` and `Unlocks` badges on goal cards
- host-centric filter chips such as `main`, `homeserver`, `homeserver-vm`
- service-centric filter chips such as `backup`, `LGTM`, `deploy-rs`

### Exit Condition

The dashboard should make it obvious what command or dependency is relevant to
each active goal.

## Wave 3

Wave 3 is implemented in the dashboard: closure-size, invariant, and
validation-health signals now surface cost, drift, and proof-of-health.

### Scope

- closure sizes per host
- closure size delta from a comparison point
- invariant/check failures
- build or validation metadata if persisted later
- summary counts for failures and regressions

### Candidate Features

- closure size table or per-host badge
- "changed most" highlight for large closure jumps
- invariant status panel sourced from existing checks
- "last successful validation" metadata once a stable source exists

### Exit Condition

The dashboard should show not only what is configured and planned, but also
what looks expensive, broken, or stale.

## Tracking

Wave 1, Wave 2, and Wave 3 should stay listed in `docs/goals.md` so they remain
visible as first-class roadmap items rather than disappearing into this design
doc.
