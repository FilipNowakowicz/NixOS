# Plaintext Secrets Allowlist Trust Model

**Date:** 2026-04-23
**Status:** Approved

## Problem

The `no-plaintext-secrets` pre-commit hook checks staged file content via `git show ":$path"` but reads the allowlist from the working tree filesystem. A working-tree-only edit to `.plaintext-secrets-allowlist` (unstaged) can silently suppress a detection — the bypass never appears in git history.

## Goal

Ensure that an allowlist bypass is always traceable in git history. Working-tree-only edits to the allowlist must have no effect on the hook.

## Decision

Read the allowlist from the **git index** (staged version) instead of the working tree.

## Change

In `pre-commit-hooks.nix`, `is_allowlisted()`:

```bash
# Before
done < "$allowlist_file"

# After
done < <(git show ":$allowlist_file" 2>/dev/null)
```

The `2>/dev/null` silently handles the case where the allowlist file has never been staged (returns not-allowlisted for all paths, which is the safe default).

## Behaviour After Change

- **Unstaged** allowlist edits: ignored entirely
- **Staged** allowlist edits: take effect immediately — you can stage the allowlist entry and the flagged file in the same commit
- **No allowlist file in index**: all paths are checked (safe default)

## Error Message Update

Change the hint on detection from:

> Add a justified path to `.plaintext-secrets-allowlist` if this is intentional.

To:

> Stage an entry in `.plaintext-secrets-allowlist` and re-run the commit if this is intentional.

This tells the user exactly what to do under the new flow.

## Workflow

To bypass a false positive:

1. Add the path to `.plaintext-secrets-allowlist`
2. Stage both the allowlist file and the flagged file
3. Commit — the bypass is recorded in history alongside the file it covers
