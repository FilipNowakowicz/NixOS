# Automated Weekly Flake Updates Design

**Date:** 2026-04-22  
**Status:** Approved  
**Goal:** Implement weekly automated `nix flake update` with GitHub Actions, auto-merge, and closure-diff bot integration.

---

## Overview

A GitHub Actions workflow runs every Friday at 6 PM UTC, runs `nix flake update`, opens (or updates) a PR to `main`, and automatically merges once all CI checks pass. The existing closure-diff bot provides visibility into the impact; CI failures leave the PR open for manual investigation.

---

## Workflow Architecture

### Scheduled Job

- **Trigger:** Weekly schedule, Friday 6 PM UTC (cron: `0 18 * * 5`)
- **Runs on:** `ubuntu-latest`
- **Branch:** Uses a persistent `flake-update` branch

### Execution Steps

1. Checkout `main`
2. Reset `flake-update` branch to `main` (cleans state from previous week)
3. Checkout `flake-update` branch
4. Install Nix
5. Run `nix flake update` (updates `flake.lock` in place)
6. Use `peter-evans/create-pull-request` to:
   - Commit the updated `flake.lock` with message `"chore: update flake.lock (weekly)"`
   - Create or update PR to `main`
   - Enable auto-merge on the PR

### PR Metadata

- **Title:** `[bot] weekly flake update`
- **Description:** Lists input names and notes that PR auto-merges if all checks pass
- **Assignees/Labels:** None (kept minimal)

---

## Branch Protection & Auto-Merge

### Branch Protection Rule

The `flake-update` branch requires all status checks to pass before merging:

- `flake-check` (flake syntax, host builds, linting)
- `closure-diff` (comment-only, no blocker)
- `smoke-test` (if homeserver paths changed)

### Auto-Merge

Once all required checks pass, GitHub's native auto-merge feature (via `peter-evans/create-pull-request`'s `auto-merge: true` option) automatically merges the PR. Merge strategy: squash or merge (user preference, default: merge commit to preserve closure-diff history).

---

## Closure-Diff Integration

The existing closure-diff job (triggered on all PRs) automatically:

1. Builds closures from `main` and the PR branch
2. Computes diffs using `nvd`
3. Posts a markdown comment showing package changes and size deltas

This comment appears before auto-merge, serving as a final safety check. Users can see real impact (e.g., "gcc bumped, +500MB") before the PR merges.

---

## Error Handling

### CI Failure

If any check fails (e.g., a host build breaks), the PR remains open without auto-merge. User receives notification and must investigate before manually merging or re-running the workflow.

### Conflicting Local Changes

If local uncommitted changes exist on `flake.lock` when the workflow runs, `git commit` fails and the workflow exits. The next Friday run will retry. User must resolve conflicts manually.

### Existing Open PR

If a PR from the previous week hasn't merged, `peter-evans/create-pull-request` updates the existing PR's branch (force-push with new commits from the fresh reset). This consolidates updates into one PR per cycle.

### Idempotency

Running the workflow multiple times in the same week produces the same PR state (same branch, same flake.lock). No duplicate PRs are created.

---

## Implementation Checklist

1. Create `.github/workflows/flake-update.yml`
2. Add branch protection rule for `flake-update` branch (require checks)
3. Enable auto-merge on branch (via workflow action)
4. Test with manual workflow trigger before Friday schedule takes effect

---

## Success Criteria

- Workflow runs on Friday at 6 PM UTC without manual intervention
- PR opens with updated `flake.lock`
- Closure-diff bot comments with size changes
- PR auto-merges if all CI passes
- PR stays open for manual review if CI fails
- No duplicate PRs created across weeks
