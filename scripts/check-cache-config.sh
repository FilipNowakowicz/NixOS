#!/usr/bin/env bash
set -euo pipefail

repo_root="$(
  git rev-parse --show-toplevel 2>/dev/null || pwd
)"
cd "$repo_root"

extract_first_match() {
  local pattern=$1
  local file=$2

  if command -v rg >/dev/null 2>&1; then
    rg -o "$pattern" "$file" | head -n 1
  else
    grep -Eo "$pattern" "$file" | head -n 1
  fi
}

setup_cache_url="$(extract_first_match 'https://[^[:space:]]+r2\.dev' .github/actions/setup-nix/action.yml)"
main_cache_url="$(extract_first_match 'https://[^"]+r2\.dev' hosts/main/default.nix)"

setup_cache_key="$(
  sed -n 's/.*trusted-public-keys = .* \(nix-cache-1:[^[:space:]]*\).*/\1/p' \
    .github/actions/setup-nix/action.yml |
    head -n 1
)"
main_cache_key="$(
  sed -n 's/.*"\(nix-cache-1:[^"]*\)".*/\1/p' hosts/main/default.nix | head -n 1
)"

if [[ -z $setup_cache_url || -z $main_cache_url || -z $setup_cache_key || -z $main_cache_key ]]; then
  echo "Unable to extract cache configuration from setup-nix or hosts/main." >&2
  exit 1
fi

if [[ $setup_cache_url != "$main_cache_url" ]]; then
  echo "Cache URL mismatch:" >&2
  echo "  setup-nix:  $setup_cache_url" >&2
  echo "  hosts/main: $main_cache_url" >&2
  exit 1
fi

if [[ $setup_cache_key != "$main_cache_key" ]]; then
  echo "Cache public key mismatch:" >&2
  echo "  setup-nix:  $setup_cache_key" >&2
  echo "  hosts/main: $main_cache_key" >&2
  exit 1
fi

echo "cache config matches"
