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
  local cache_file="/tmp/closure-${sha:0:8}-${host}.path"

  if [[ -f $cache_file ]]; then
    local cached_path
    cached_path="$(<"$cache_file")"
    if [[ -n $cached_path && -e $cached_path ]]; then
      echo "$cached_path"
      return 0
    fi
    rm -f "$cache_file"
  fi

  echo "Building closure for $sha:$host..." >&2
  local store_path
  if ! store_path="$(
    nix build "github:$REPO/$sha#nixosConfigurations.$host.config.system.build.toplevel" \
      --print-out-paths --no-link --show-trace
  )"; then
    echo "" # Return empty string on failure
    return 0
  fi

  store_path="$(echo "$store_path" | tail -n 1)"
  if [[ -z $store_path ]]; then
    echo ""
    return 0
  fi

  printf '%s\n' "$store_path" > "$cache_file"
  echo "$store_path"
}

format_diff_table() {
  local base_closure=$1
  local target_closure=$2

  local nvd_output
  if ! nvd_output="$(
    nix run nixpkgs#nvd -- diff "$base_closure" "$target_closure" 2>&1
  )"; then
    echo "Failed to diff closures:" >&2
    echo "$nvd_output" >&2
    return 1
  fi

  local table="| Package | Old | New | Δ | Δ% |"$'\n'"| --- | --- | --- | --- | --- |"
  local row_count=0
  local line

  while IFS= read -r line; do
    local package
    package=$(echo "$line" | sed -E 's/^\s+([^:]+):.*/\1/')
    local old_size
    old_size=$(echo "$line" | sed -E 's/.*: ([0-9.]+[KMG]?B?) -> .*/\1/')
    local new_size
    new_size=$(echo "$line" | sed -E 's/.*-> ([0-9.]+[KMG]?B?) .*/\1/')

    if [[ -z $old_size ]] || [[ -z $new_size ]]; then
      continue
    fi

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
    row_count=$((row_count + 1))
  done < <(grep -E '^\s+\S+:' <<<"$nvd_output")

  if [[ $row_count -eq 0 ]]; then
    table+=$'\n'"| No package-level closure delta | - | - | - | - |"
  fi

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
