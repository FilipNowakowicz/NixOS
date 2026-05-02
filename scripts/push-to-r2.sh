#!/usr/bin/env bash
# Push the outputs of a validate.sh command to the R2 binary cache.
# Usage: push-to-r2.sh <validate.sh args...>
# Env: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, CACHE_SIGNING_KEY
set -euo pipefail

: "${R2_ACCESS_KEY_ID:?}"
: "${R2_SECRET_ACCESS_KEY:?}"
: "${CACHE_SIGNING_KEY:?}"

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$CACHE_SIGNING_KEY" >"$KEY_FILE"

R2_STORE="s3://nix-cache?endpoint=https://89d783d5aa24b5311bc8564fa7602456.r2.cloudflarestorage.com&region=auto&secret-key=$KEY_FILE"

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"

script_dir="$(cd "$(dirname "$0")" && pwd)"

mapfile -t paths < <(PRINT_PATHS=1 bash "$script_dir/validate.sh" "$@")

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "No paths to push." >&2
  exit 0
fi

echo "Pushing ${#paths[@]} path(s) to R2..."
nix copy --to "$R2_STORE" "${paths[@]}"
