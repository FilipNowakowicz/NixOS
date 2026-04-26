#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-secrets-directory.sh [--staged|--working-tree]

Validate files under hosts/*/secrets/*.

Allowed:
- encrypted blobs ending in .enc or .age
- YAML files ending in .yaml or .yml that contain a top-level "sops:" block
EOF
}

mode="${1:---working-tree}"

case "$mode" in
--staged | --working-tree) ;;
-h | --help)
  usage
  exit 0
  ;;
*)
  usage >&2
  exit 1
  ;;
esac

repo_root="$(
  git rev-parse --show-toplevel 2>/dev/null || pwd
)"

cd "$repo_root"

has_failed=0

validate_path() {
  local path="$1"

  case "$path" in
  *.enc | *.age)
    return 0
    ;;
  *.yaml | *.yml)
    local has_sops=1
    if [[ $mode == "--staged" ]]; then
      if git show ":$path" 2>/dev/null | grep -Eq '^[[:space:]]*sops:'; then
        has_sops=0
      fi
    elif grep -Eq '^[[:space:]]*sops:' "$path"; then
      has_sops=0
    fi

    if [[ $has_sops -eq 0 ]]; then
      return 0
    fi

    echo "Plaintext YAML is not allowed under secrets directories: $path" >&2
    echo "Only SOPS-managed YAML files with a 'sops:' block may live there." >&2
    return 1
    ;;
  *)
    echo "Unsupported file in secrets directory: $path" >&2
    echo "Allowed file types are .enc, .age, and SOPS-managed .yaml/.yml." >&2
    return 1
    ;;
  esac
}

while IFS= read -r -d '' path; do
  if ! validate_path "$path"; then
    has_failed=1
  fi
done < <(
  if [[ $mode == "--staged" ]]; then
    git diff --cached --name-only --diff-filter=ACMR -z -- ':(glob)hosts/*/secrets/*'
  elif [[ -d hosts ]]; then
    find hosts -type f -path '*/secrets/*' -print0 | sort -z
  fi
)

exit "$has_failed"
