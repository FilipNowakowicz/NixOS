#!/usr/bin/env bash
# Emit compact metadata for tracked repo files.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$repo_root"

printf 'path\tarea\tkind\tsignals\n'

git ls-files -z |
  while IFS= read -r -d '' path; do
    area=${path%%/*}
    [ "$area" = "$path" ] && area=root

    # shellcheck disable=SC2221,SC2222
    case "$path" in
    .github/workflows/*.yml | .github/workflows/*.yaml) kind="github-workflow" ;;
    .agents/skills/*/SKILL.md) kind="agent-skill" ;;
    .agents/*/scripts/*.sh | scripts/*.sh) kind="shell-script" ;;
    hosts/*/CLAUDE.md) kind="host-runbook" ;;
    hosts/*/*.nix | hosts/*/*/*.nix) kind="host-module" ;;
    modules/nixos/profiles/*.nix | modules/nixos/profiles/*/*.nix) kind="nixos-profile" ;;
    modules/home-manager/*.nix | modules/home-manager/*/*.nix) kind="home-manager-module" ;;
    modules/nixos/*.nix | modules/nixos/*/*.nix) kind="nixos-module" ;;
    lib/*.nix | lib/*/*.nix) kind="nix-lib" ;;
    tests/*.nix | tests/*/*.nix) kind="nix-test" ;;
    packages/*.nix | packages/*/*.nix) kind="package" ;;
    docs/*.md | docs/*/*.md) kind="doc" ;;
    *.nix) kind="nix" ;;
    *.md) kind="doc" ;;
    *.sh) kind="shell-script" ;;
    *) kind="file" ;;
    esac

    signals=$(printf '%s' "$path" |
      tr '/._-' '    ' |
      tr '[:upper:]' '[:lower:]' |
      tr -s ' ')

    printf '%s\t%s\t%s\t%s\n' "$path" "$area" "$kind" "$signals"
  done
