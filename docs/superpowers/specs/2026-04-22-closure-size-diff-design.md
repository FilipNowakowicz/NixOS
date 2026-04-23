# Closure-Size Diff CI Design

## Overview

Add automated closure-size diffing to GitHub Actions that comments on PRs with the change in NixOS closure sizes for production hosts (main and homeserver). Catches surprise pulls of large/bloated transitive dependencies.

## Goals

- Detect unexpected increases in system closure size
- Provide visibility into what packages changed and by how much
- Block nothing — if diff fails, log a note and continue
- Keep PR comments readable without losing detail

## Architecture

### Scope

- Monitor **two hosts**: `main` (primary machine) and `homeserver` (real hardware)
- Skip `vm` and `homeserver-vm` (development environments where variance is expected)
- Monitor **full system closures** (catches transitive dependency bloat)

### Workflow

**After build step succeeds**, add new CI steps:

1. **Setup base closure**
   - Checkout base branch (main)
   - Build `nixosConfigurations.main` and `nixosConfigurations.homeserver` for base SHA
   - Store closure paths for diff

2. **Compute deltas**
   - Build current branch's `nixosConfigurations.main` and `nixosConfigurations.homeserver`
   - Run `nvd diff` for each host: `nvd diff base_closure current_closure`
   - Parse output to extract: package name, old size, new size, delta

3. **Format and post comment**
   - Generate markdown table of top 10 packages by absolute delta (largest first)
   - Include both growth and shrinkage
   - Add collapsible `<details>` block with full `nvd` output
   - Highlight if total closure growth exceeds 5% (informational, not blocking)

### Error Handling

- **Base build fails**: Skip the job entirely. Log "couldn't compute diff" and exit 0.
- **Current build fails**: Blocked by existing flake-check job, so won't reach this point.
- **Diff computation fails**: Post comment "nvd diff failed for {host}" and continue (exit 0).

### Implementation Details

**PR Comment Structure:**

```
## Closure Size Report

### main
| Package | Old | New | Δ | Δ% |
| --- | --- | --- | --- | --- |
| package1 | 150MB | 200MB | +50MB | +33% |
| package2 | 80MB | 70MB | -10MB | -12.5% |
...

**Total delta:** -5MB (-0.1%)

### homeserver
...

<details>
<summary>Full nvd output</summary>

[full nvd diff output here]
</details>
```

**Threshold logic:**

- If total closure growth > 5% (configurable), add a line: "Total closure grew >5%" (informational, non-blocking)

## Testing

- Manual test: create a PR that adds a large dependency (e.g., gcc)
- Verify comment appears with correct delta
- Verify comment only appears on PRs (not on `push` to main)

## Future Enhancements

- Configurable size thresholds per host
- Historical tracking (show trend over time)
- Extend to vm/homeserver-vm if closure management becomes important there
