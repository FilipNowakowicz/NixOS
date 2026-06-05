#!/usr/bin/env bash
# Build a compact TSV routing index for learning candidates.
set -euo pipefail

root=${1:-.agents/learning}
candidate_dir="$root/candidates"

printf 'path\tid\tstatus\texpires\ttype\troute\tbest_form\tdedupe_key\ttriggers\ttargets\tevidence\n'

[ -d "$candidate_dir" ] || exit 0

find "$candidate_dir" -maxdepth 1 -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) |
  sort |
  while IFS= read -r path; do
    field() {
      local name=$1
      sed -n "s/^${name}:[[:space:]]*//p" "$path" | head -1 |
        tr '\t' ' ' |
        sed "s/^\"//; s/\"$//; s/^'//; s/'$//"
    }

    id=$(field id)
    status=$(field status)
    expires=$(field expires)
    type=$(field type)
    route=$(field route)
    best_form=$(field best_form)
    dedupe_key=$(field dedupe_key)
    triggers=$(field triggers)
    targets=$(field targets)
    evidence=$(field evidence)

    [ -n "$id" ] || id=$(basename "$path")
    [ -n "$status" ] || status=unknown

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$path" "$id" "$status" "$expires" "$type" "$route" "$best_form" \
      "$dedupe_key" "$triggers" "$targets" "$evidence"
  done
