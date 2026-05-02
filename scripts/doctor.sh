#!/usr/bin/env bash
set -euo pipefail

repo_root="$(
  git rev-parse --show-toplevel 2>/dev/null || pwd
)"
cd "$repo_root"

run() {
  printf '==> %s\n' "$*"
  "$@"
}

run bash scripts/validate.sh docs
run bash scripts/test-ci-plan.sh
run bash scripts/check-cache-config.sh
run bash scripts/check-secrets-directory.sh --working-tree
run bash scripts/validate.sh flake-eval
run nix fmt -- --fail-on-change

if [[ ${1:-} == "--with-builds" ]]; then
  run bash scripts/validate.sh light
  run bash scripts/validate.sh package inventory
fi
