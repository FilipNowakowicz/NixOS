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
REPO="${GITHUB_REPOSITORY:-}"

if [[ -z $BASE_REF ]] || [[ -z $TARGET_REF ]] || [[ -z $HOST ]]; then
  echo "Usage: $0 <base_ref> <target_ref> <host>" >&2
  exit 1
fi

if [[ -z $REPO ]]; then
  ORIGIN_URL="$(git config --get remote.origin.url || true)"
  if [[ $ORIGIN_URL =~ github\.com[:/]([^[:space:]]+)$ ]]; then
    REPO="${BASH_REMATCH[1]%.git}"
  fi
fi

if [[ -z $REPO ]] || [[ $REPO != */* ]]; then
  echo "Unable to determine GitHub repository. Set GITHUB_REPOSITORY=owner/repo." >&2
  exit 1
fi

build_closure() {
  local sha=$1
  local host=$2
  local output_dir="/tmp/closure-${sha:0:8}-${host}"

  if [[ -d $output_dir ]]; then
    echo "$output_dir/result"
    return 0
  fi

  mkdir -p "$output_dir"

  echo "Building closure for $sha:$host..." >&2
  if ! nix build "github:$REPO/$sha#nixosConfigurations.$host.config.system.build.toplevel" \
    --out-link "$output_dir/result" --no-link 2>/dev/null; then
    echo "" # Return empty string on failure
    return 1
  fi

  echo "$output_dir/result"
}

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
    local package
    package=$(echo "$line" | sed -E 's/^\s+([^:]+):.*/\1/')
    local old_size
    old_size=$(echo "$line" | sed -E 's/.*: ([0-9.]+[KMG]?B?) -> .*/\1/')
    local new_size
    new_size=$(echo "$line" | sed -E 's/.*-> ([0-9.]+[KMG]?B?) .*/\1/')

    # Skip if we couldn't parse
    if [[ -z $old_size ]] || [[ -z $new_size ]]; then
      continue
    fi

    # Convert to bytes for calculation
    local old_bytes
    old_bytes=$(echo "$old_size" | numfmt --from=auto 2>/dev/null || echo 0)
    local new_bytes
    new_bytes=$(echo "$new_size" | numfmt --from=auto 2>/dev/null || echo 0)
    local delta_bytes=$((new_bytes - old_bytes))
    local delta_pct=0

    if [[ $old_bytes -gt 0 ]]; then
      delta_pct=$(((delta_bytes * 100) / old_bytes))
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

BASE_SHA=$(git rev-parse "$BASE_REF")
TARGET_SHA=$(git rev-parse "$TARGET_REF")

BASE_CLOSURE=$(build_closure "$BASE_SHA" "$HOST")
if [[ -z $BASE_CLOSURE ]]; then
  echo "Failed to build base closure for $HOST" >&2
  exit 1
fi

TARGET_CLOSURE=$(build_closure "$TARGET_SHA" "$HOST")
if [[ -z $TARGET_CLOSURE ]]; then
  echo "Failed to build target closure for $HOST" >&2
  exit 1
fi

echo "## $HOST"
format_diff_table "$BASE_CLOSURE" "$TARGET_CLOSURE"
