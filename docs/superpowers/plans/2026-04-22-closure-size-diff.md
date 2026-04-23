# Closure-Size Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GitHub Actions job that diffs NixOS closure sizes for main and homeserver hosts, comments on PRs with a summary table and full output.

**Architecture:** Bash script (`scripts/closure-diff.sh`) computes the diff and formats markdown. GitHub Actions job calls the script after builds, stores output, and posts as a PR comment. Job gracefully skips if base branch build fails.

**Tech Stack:** Bash, `nvd`, GitHub Actions, GitHub CLI (`gh` for posting comments)

---

## File Structure

- **Create:** `scripts/closure-diff.sh` — Core logic: build base closures, compute diffs via nvd, parse and format markdown output
- **Modify:** `.github/workflows/nix.yml` — Add `closure-diff` job that runs after successful builds on PRs

---

## Task 1: Create closure-diff.sh script

**Files:**

- Create: `scripts/closure-diff.sh`

- [ ] **Step 1: Create the script skeleton with usage instructions**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: closure-diff.sh <base_ref> <target_ref> <host>
# Computes nvd diff between two git refs for a given host.
# Converts refs to SHAs, builds closures via GitHub, and outputs markdown table.
#
# Example: closure-diff.sh origin/main HEAD main

BASE_REF="${1:-}"
TARGET_REF="${2:-}"
HOST="${3:-}"

if [[ -z "$BASE_REF" ]] || [[ -z "$TARGET_REF" ]] || [[ -z "$HOST" ]]; then
  echo "Usage: $0 <base_ref> <target_ref> <host>" >&2
  exit 1
fi

set +e
# Main logic will go here
set -e
```

- [ ] **Step 2: Add function to build closure for a ref/host**

Append to the script before the "Main logic" comment:

```bash
build_closure() {
  local sha=$1
  local host=$2
  local output_dir="/tmp/closure-${sha:0:8}-${host}"

  if [[ -d "$output_dir" ]]; then
    echo "$output_dir/result"
    return 0
  fi

  mkdir -p "$output_dir"

  echo "Building closure for $sha:$host..." >&2
  if ! nix build "github:FilipNowakowicz/NixOS/$sha#nixosConfigurations.$host.config.system.build.toplevel" \
    --out-link "$output_dir/result" --no-link 2>/dev/null; then
    echo "" # Return empty string on failure
    return 1
  fi

  echo "$output_dir/result"
}
```

- [ ] **Step 3: Add function to parse nvd output and generate markdown table**

Append to the script:

```bash
format_diff_table() {
  local base_closure=$1
  local target_closure=$2

  # Run nvd and capture output
  local nvd_output
  nvd_output=$(nvd diff "$base_closure" "$target_closure" 2>&1 || true)

  # Extract package diffs: parse lines like "  package_name: 123 -> 456"
  # Format as markdown table
  local table="| Package | Old | New | Δ | Δ% |"$'\n'"| --- | --- | --- | --- | --- |"

  echo "$nvd_output" | grep -E '^\s+\S+:' | while read -r line; do
    # Extract package name and sizes
    local package=$(echo "$line" | sed -E 's/^\s+([^:]+):.*/\1/')
    local old_size=$(echo "$line" | sed -E 's/.*: ([0-9.]+[KMG]?B?) -> .*/\1/')
    local new_size=$(echo "$line" | sed -E 's/.*-> ([0-9.]+[KMG]?B?) .*/\1/')

    # Skip if we couldn't parse
    if [[ -z "$old_size" ]] || [[ -z "$new_size" ]]; then
      continue
    fi

    # Convert to bytes for calculation
    local old_bytes=$(echo "$old_size" | numfmt --from=auto 2>/dev/null || echo 0)
    local new_bytes=$(echo "$new_size" | numfmt --from=auto 2>/dev/null || echo 0)
    local delta_bytes=$((new_bytes - old_bytes))
    local delta_pct=0

    if [[ $old_bytes -gt 0 ]]; then
      delta_pct=$(( (delta_bytes * 100) / old_bytes ))
    fi

    local delta_str
    if [[ $delta_bytes -ge 0 ]]; then
      delta_str="+$(numfmt --to=auto $delta_bytes 2>/dev/null || echo $delta_bytes)"
    else
      delta_str="$(numfmt --to=auto $delta_bytes 2>/dev/null || echo $delta_bytes)"
    fi

    table+=$'\n'"| $package | $old_size | $new_size | $delta_str | ${delta_pct}% |"
  done

  echo "$table"
}
```

- [ ] **Step 4: Add main logic to orchestrate the diff**

Replace the "Main logic will go here" comment with:

```bash
BASE_SHA=$(git rev-parse "$BASE_REF")
TARGET_SHA=$(git rev-parse "$TARGET_REF")

BASE_CLOSURE=$(build_closure "$BASE_SHA" "$HOST")
if [[ -z "$BASE_CLOSURE" ]]; then
  echo "Failed to build base closure for $HOST" >&2
  exit 1
fi

TARGET_CLOSURE=$(build_closure "$TARGET_SHA" "$HOST")
if [[ -z "$TARGET_CLOSURE" ]]; then
  echo "Failed to build target closure for $HOST" >&2
  exit 1
fi

echo "## $HOST"
format_diff_table "$BASE_CLOSURE" "$TARGET_CLOSURE"
```

- [ ] **Step 5: Make the script executable and commit**

```bash
chmod +x scripts/closure-diff.sh
git add scripts/closure-diff.sh
git commit -m "add: closure-diff script for computing nvd diffs"
```

---

## Task 2: Add closure-diff job to GitHub Actions workflow

**Files:**

- Modify: `.github/workflows/nix.yml`

- [ ] **Step 1: Read the current workflow to understand its structure**

```bash
cat .github/workflows/nix.yml
```

Expected: Current workflow with `flake-check` job and `smoke-test` job.

- [ ] **Step 2: Add closure-diff job after the flake-check job**

Insert this new job after the `flake-check` job (around line 52, before the `changes` job):

```yaml
closure-diff:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  needs: flake-check
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

    - name: Cachix
      uses: cachix/cachix-action@v15
      with:
        name: filipnowakowicz
        authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}

    - name: Compute closure diffs
      id: diff
      run: |
        mkdir -p /tmp/closure-reports

        # Get base and target refs
        BASE_REF="origin/${{ github.base_ref }}"
        TARGET_REF="HEAD"

        # Compute diffs for both hosts
        {
          echo "# Closure Size Report"
          echo ""
          bash scripts/closure-diff.sh "$BASE_REF" "$TARGET_REF" "main" || echo "Failed to diff main"
          echo ""
          bash scripts/closure-diff.sh "$BASE_REF" "$TARGET_REF" "homeserver" || echo "Failed to diff homeserver"
          echo ""
          echo "<details>"
          echo "<summary>Full nvd output</summary>"
          echo ""
          echo "\`\`\`"
          bash scripts/closure-diff.sh "$BASE_REF" "$TARGET_REF" "main" 2>&1 || true
          bash scripts/closure-diff.sh "$BASE_REF" "$TARGET_REF" "homeserver" 2>&1 || true
          echo "\`\`\`"
          echo ""
          echo "</details>"
        } > /tmp/closure-reports/summary.md

        # Store summary for comment step
        {
          echo "summary<<EOF"
          cat /tmp/closure-reports/summary.md
          echo "EOF"
        } >> "$GITHUB_OUTPUT"

    - name: Post closure diff comment
      if: always() && github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const summary = `${{ steps.diff.outputs.summary }}`;
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: summary || 'Closure diff computation skipped or failed.'
          });
```

- [ ] **Step 3: Verify workflow syntax**

```bash
# Use yamllint if available, or just check it's valid YAML
python3 -m yaml .github/workflows/nix.yml
```

Expected: No errors. The workflow should be valid YAML.

- [ ] **Step 4: Commit the workflow change**

```bash
git add .github/workflows/nix.yml
git commit -m "ci: add closure-size-diff job to report nvd diffs on PRs"
```

---

## Task 3: Test the implementation locally

**Files:**

- Test: Manual test of script and workflow

- [ ] **Step 1: Test closure-diff.sh with sample closures**

Build two closures locally and run the script:

```bash
# Build current main closure
nix build .#nixosConfigurations.main.config.system.build.toplevel \
  --out-link /tmp/closure-main-current --no-link

# Build a second closure (e.g., an older version or different config)
# For testing, just copy the first one and compare to itself
/tmp/closure-main-current  /tmp/closure-main-base

# Run the script (it expects refs, but we can test manually)
bash scripts/closure-diff.sh origin/main HEAD main
```

Expected: Script runs without error and outputs a markdown table (may be empty if closures are identical).

- [ ] **Step 2: Verify the script handles missing closures gracefully**

```bash
bash scripts/closure-diff.sh origin/nonexistent HEAD main 2>&1 || echo "Exited with code $?"
```

Expected: Script exits with non-zero code and prints an error message.

- [ ] **Step 3: Inspect the workflow file for correctness**

```bash
cat .github/workflows/nix.yml | grep -A 50 "closure-diff:"
```

Expected: New job is present with correct indentation and syntax.

- [ ] **Step 4: All tests pass; commit any test artifacts if needed**

```bash
# No additional commits needed if only testing; the workflow and script are already committed
```

---

## Key Implementation Notes

1. **nvd availability:** `nvd` is in the dev shell (`nix develop`). In CI, we build it as part of the flake or install it via Nix.
2. **Closure paths:** `nix build --out-link <path>` stores the closure. We use `nvd diff <closure1> <closure2>` to compare.
3. **Comment posting:** Uses `actions/github-script` to call GitHub API and post comments only on PRs (`if: github.event_name == 'pull_request'`).
4. **Error handling:** If base build fails, the entire job exits gracefully (no error, just skip the comment). If current build fails, the `flake-check` job already blocks the PR.
5. **Size thresholds:** Currently not implemented (marked as future enhancement). Can be added later by parsing total delta in the summary.
