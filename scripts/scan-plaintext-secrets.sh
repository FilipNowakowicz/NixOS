#!/usr/bin/env bash
# Scan tracked files for plaintext credentials. Mirrors the no-plaintext-secrets
# pre-commit hook, but operates on all tracked files instead of staged ones —
# intended for CI to catch anything that slipped past local hooks.
#
# Usage: scan-plaintext-secrets.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

allowlist_file=".plaintext-secrets-allowlist"
pattern='(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE KEY)-----|([a-z0-9_-]*(api[_-]?key|auth[_-]?token|access[_-]?token|secret|password|passwd)[a-z0-9_-]*[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9_+=/-]{16,}"?))'

is_valid_secrets_path() {
  local path="$1"
  case "$path" in
  *.enc | *.age)
    return 0
    ;;
  *.yaml | *.yml)
    grep -Eq '^[[:space:]]*sops:' "$path"
    return
    ;;
  *)
    return 1
    ;;
  esac
}

is_allowlisted() {
  local path="$1"
  [[ -f $allowlist_file ]] || return 1
  while IFS= read -r line; do
    [[ -z $line || $line =~ ^[[:space:]]*# ]] && continue
    # shellcheck disable=SC2053
    if [[ $path == $line ]]; then
      return 0
    fi
  done <"$allowlist_file"
  return 1
}

has_failed=0
while IFS= read -r path; do
  [[ -z $path || ! -f $path ]] && continue

  case "$path" in
  hosts/*/secrets/*)
    if is_valid_secrets_path "$path"; then
      continue
    fi
    echo "Invalid file under hosts/*/secrets/*: $path" >&2
    echo "Allowed file types are .enc, .age, and SOPS-managed .yaml/.yml." >&2
    has_failed=1
    continue
    ;;
  esac

  case "$path" in
  *.enc | *.age | .sops.yaml | flake.lock | result | result-*)
    continue
    ;;
  esac

  if is_allowlisted "$path"; then
    continue
  fi

  if grep -Einq "$pattern" "$path"; then
    echo "Potential plaintext secret in: $path" >&2
    has_failed=1
  fi
done < <(git ls-files)

exit "$has_failed"
