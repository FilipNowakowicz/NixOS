# Automated Weekly Flake Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a weekly GitHub Actions workflow that automatically updates `flake.lock`, opens a PR, and auto-merges when CI passes.

**Architecture:** A scheduled workflow (`flake-update.yml`) runs Friday 6 PM UTC, executes `nix flake update`, commits changes to a persistent `flake-update` branch, and uses `peter-evans/create-pull-request` to open/update the PR. Branch protection rules require all checks to pass before auto-merge. The existing closure-diff bot provides impact visibility.

**Tech Stack:** GitHub Actions, Nix, peter-evans/create-pull-request@v6

---

## File Structure

- **Create:** `.github/workflows/flake-update.yml` — scheduled workflow for weekly flake updates
- **No modifications to existing files** — workflow is self-contained

---

## Task 1: Create the flake-update workflow file

**Files:**

- Create: `.github/workflows/flake-update.yml`

- [ ] **Step 1: Create the workflow file with scheduled and manual triggers**

Create `.github/workflows/flake-update.yml`:

```yaml
name: Flake update

on:
  schedule:
    # Friday 6 PM UTC
    - cron: "0 18 * * 5"
  workflow_dispatch:

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

jobs:
  update:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install Nix
        uses: cachix/install-nix-action@v27
        with:
          nix_path: nixpkgs=channel:nixos-unstable
          extra_nix_config: |
            experimental-features = nix-command flakes

      - name: Reset flake-update branch to main
        run: |
          git fetch origin main
          git checkout -B flake-update origin/main

      - name: Update flake.lock
        run: nix flake update

      - name: Create or update Pull Request
        uses: peter-evans/create-pull-request@v6
        with:
          commit-message: "chore: update flake.lock (weekly)"
          title: "[bot] weekly flake update"
          body: |
            Automated weekly update of flake.lock.

            This PR auto-merges if all checks pass. Review the closure-diff comment below for impact on system size.
          branch: flake-update
          delete-branch: false
          auto-merge-method: squash
```

- [ ] **Step 2: Verify the workflow file syntax**

Run:

```bash
cd /home/user/nix
nix fmt .github/workflows/flake-update.yml
```

Expected: File is formatted (no errors).

- [ ] **Step 3: Commit the workflow file**

```bash
git add .github/workflows/flake-update.yml
git commit -m "feat: add weekly flake update workflow"
```

Expected: Commit succeeds, workflow file is staged and committed.

---

## Task 2: Test the workflow with manual trigger

**Files:**

- Reference: `.github/workflows/flake-update.yml`
- Reference: `.github/workflows/nix.yml` (existing CI for verification)

- [ ] **Step 1: Push the workflow to GitHub**

```bash
git push origin main
```

Expected: Workflow file is pushed to `main` branch. GitHub detects the new workflow.

- [ ] **Step 2: Trigger the workflow manually via GitHub CLI**

```bash
gh workflow run flake-update.yml --ref main
```

Expected: Workflow is queued. You see confirmation message "✓ Triggered workflow run".

- [ ] **Step 3: Monitor workflow execution**

```bash
gh run list --workflow=flake-update.yml --limit=1
```

Wait for the workflow to complete (2-3 minutes). Run:

```bash
gh run view --workflow=flake-update.yml --exit-status
```

Expected: All steps pass. Specifically:

- "Update flake.lock" completes
- "Create or update Pull Request" completes

- [ ] **Step 4: Verify PR was created**

```bash
gh pr list --state=open --search="flake-update" --limit=5
```

Expected: One open PR titled "[bot] weekly flake update" is listed. Note the PR number.

- [ ] **Step 5: Verify PR contents**

```bash
gh pr view <PR_NUMBER>
```

Expected: PR shows:

- Branch: `flake-update`
- Title: `[bot] weekly flake update`
- Body mentions auto-merge behavior
- Head of PR is a commit on `flake-update` branch with message "chore: update flake.lock (weekly)"

- [ ] **Step 6: Check that flake.lock was actually updated**

```bash
gh pr diff <PR_NUMBER>
```

Expected: Output shows changes to `flake.lock` (additions/removals of input revisions). Confirms `nix flake update` ran.

- [ ] **Step 7: Wait for CI to complete on the PR**

Monitor the PR checks:

```bash
gh pr checks <PR_NUMBER>
```

Expected: All checks pass:

- `flake-check` ✓
- `closure-diff` ✓ (will post a comment)
- `smoke-test` (runs only if homeserver paths changed)

- [ ] **Step 8: Verify closure-diff bot comment exists**

```bash
gh pr view <PR_NUMBER> --json comments --jq '.comments[] | select(.body | contains("Closure Size Report"))'
```

Expected: Comment exists showing package changes and size deltas.

- [ ] **Step 9: Commit test result notes**

No code commit needed. Verify in git log that the workflow file is present:

```bash
git log --oneline -1
```

Expected: Latest commit shows the workflow file addition (or earlier commits if you haven't pushed yet).

---

## Task 3: Configure branch protection rule

**Files:**

- Reference: GitHub repository settings (web UI)

- [ ] **Step 1: Open GitHub repository settings**

Navigate to: `https://github.com/FilipNowakowicz/NixOS/settings/branches`

- [ ] **Step 2: Add branch protection rule for `flake-update`**

Click "Add rule". In the "Branch name pattern" field, enter: `flake-update`

- [ ] **Step 3: Configure protection settings**

Enable the following:

- ✓ "Require status checks to pass before merging"
  - Select the following checks (they appear after the first PR runs CI):
    - `flake-check`
    - `closure-diff` (optional — currently comment-only, doesn't block)
    - `smoke-test` (if you want it to block; it only runs when homeserver paths change)

- [ ] **Step 4: Enable auto-merge**

In the same rule settings, enable:

- ✓ "Allow auto-merge"

Select merge method: "Squash and merge" or "Create a merge commit" (both work; default to squash for cleaner history on main).

- [ ] **Step 5: Save the rule**

Click "Create". The rule is now active.

Expected: Branch `flake-update` now requires checks to pass and allows auto-merge.

---

## Task 4: Verify auto-merge behavior with a manual test

**Files:**

- Reference: `.github/workflows/flake-update.yml`
- Reference: GitHub PR from Task 2

- [ ] **Step 1: Enable auto-merge on the test PR**

If the PR from Task 2 still exists and all checks pass:

```bash
gh pr merge <PR_NUMBER> --auto --squash
```

Expected: Output confirms auto-merge is enabled: "Pull request #X will be auto-merged..."

- [ ] **Step 2: Wait for auto-merge to complete**

Monitor the PR:

```bash
gh pr view <PR_NUMBER>
```

Wait ~1-2 minutes. Re-run the command.

Expected: PR status changes to "Merged" (green checkmark). Branch `flake-update` is not deleted (set in workflow).

- [ ] **Step 3: Verify main was updated**

```bash
git fetch origin main
git log --oneline -5
```

Expected: Latest commit on main shows "chore: update flake.lock (weekly)" from the bot's action.

- [ ] **Step 4: Verify flake.lock is updated on main**

```bash
git diff HEAD~1 flake.lock | head -20
```

Expected: Shows changes to `flake.lock` (input revisions updated).

---

## Task 5: Final verification and cleanup

**Files:**

- Reference: `.github/workflows/flake-update.yml`
- Reference: `.github/workflows/nix.yml`

- [ ] **Step 1: Verify workflow is scheduled**

```bash
gh workflow list
```

Expected: `flake-update.yml` is listed with status "Active".

- [ ] **Step 2: Verify cron schedule is correct**

Check `.github/workflows/flake-update.yml`:

```bash
grep -A2 "schedule:" .github/workflows/flake-update.yml
```

Expected: Cron line shows `'0 18 * * 5'` (Friday 6 PM UTC).

- [ ] **Step 3: Verify no conflicts with existing workflows**

```bash
gh workflow list --all
```

Expected: `flake-update.yml` and `nix.yml` both listed. No naming conflicts.

- [ ] **Step 4: Document the workflow in CLAUDE.md or README (optional)**

Update the project README or CLAUDE.md to document:

- Weekly flake updates run automatically Friday 6 PM UTC
- PR is opened and auto-merges if CI passes
- Closure-diff comment shows impact
- Manual override: `gh workflow run flake-update.yml --ref main`

This is optional but useful for future reference.

- [ ] **Step 5: Final commit and push**

```bash
git status
```

Expected: No uncommitted changes (workflow file already committed in Task 1).

```bash
git log --oneline -5
```

Expected: Shows workflow addition and flake.lock update in history.

---

## Summary

After completing all tasks:

- ✓ Workflow file created and pushed to GitHub
- ✓ Workflow runs on schedule (Friday 6 PM UTC) and can be manually triggered
- ✓ PR is created/updated on `flake-update` branch
- ✓ Closure-diff bot comments with impact
- ✓ Branch protection enforces check requirements
- ✓ Auto-merge enabled and tested
- ✓ Main branch receives weekly updates automatically

The workflow is now fully operational.
