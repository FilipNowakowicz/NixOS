#!/usr/bin/env bash
set -euo pipefail

system="${SYSTEM:-x86_64-linux}"

repo_root="$(
  git rev-parse --show-toplevel 2>/dev/null || pwd
)"

cd "$repo_root"

build_attrs() {
  nix build "$@" --no-link --show-trace
}

show_report_attrs() {
  local output
  while IFS= read -r output; do
    cat "$output"
    printf '\n'
  done < <(nix build "$@" --no-link --print-out-paths --show-trace)
}

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  flake-eval         Run flake evaluation only (no builds)
  light              Build lightweight blocking checks
  host <name>        Build one host closure: main-ci, vm, homeserver, homeserver-vm
  hosts              Build all host system closures used in CI
  profile-test <name>
                     Build one profile test: profile-security, profile-observability, profile-hardening
  smoke-vm           Build the desktop VM smoke test
  smoke-homeserver   Build the homeserver-vm smoke test
  profile-tests      Build all profile NixOS tests
  heavy              Build all smoke and profile tests
  cve-reports        Build and print the CVE report outputs
EOF
}

command="${1:-}"
target="${2:-}"

build_host() {
  case "$1" in
  main-ci)
    build_attrs ".#nixosConfigurations.main-ci.config.system.build.toplevel"
    ;;
  vm)
    build_attrs ".#nixosConfigurations.vm.config.system.build.toplevel"
    ;;
  homeserver)
    build_attrs ".#nixosConfigurations.homeserver.config.system.build.toplevel"
    ;;
  homeserver-vm)
    build_attrs ".#nixosConfigurations.homeserver-vm.config.system.build.toplevel"
    ;;
  *)
    echo "Unknown host target: $1" >&2
    exit 1
    ;;
  esac
}

build_profile_test() {
  case "$1" in
  profile-security)
    build_attrs ".#legacyPackages.${system}.ciTests.profile-security"
    ;;
  profile-observability)
    build_attrs ".#legacyPackages.${system}.ciTests.profile-observability"
    ;;
  profile-hardening)
    build_attrs ".#legacyPackages.${system}.ciTests.profile-hardening"
    ;;
  *)
    echo "Unknown profile test target: $1" >&2
    exit 1
    ;;
  esac
}

case "$command" in
flake-eval)
  nix flake check --no-build --show-trace
  ;;

light)
  build_attrs \
    ".#checks.${system}.deploy-activate" \
    ".#checks.${system}.deploy-schema" \
    ".#checks.${system}.invariants-main" \
    ".#checks.${system}.invariants-vm" \
    ".#checks.${system}.invariants-homeserver" \
    ".#checks.${system}.invariants-homeserver-vm" \
    ".#checks.${system}.homeserver-sops-bootstrap" \
    ".#checks.${system}.lib-generators" \
    ".#checks.${system}.lib-generators-golden" \
    ".#checks.${system}.lib-acl"
  ;;

host)
  build_host "${target:?Usage: $0 host <name>}"
  ;;

hosts)
  build_attrs \
    ".#nixosConfigurations.main-ci.config.system.build.toplevel" \
    ".#nixosConfigurations.vm.config.system.build.toplevel" \
    ".#nixosConfigurations.homeserver.config.system.build.toplevel" \
    ".#nixosConfigurations.homeserver-vm.config.system.build.toplevel"
  ;;

smoke-vm)
  build_attrs ".#legacyPackages.${system}.ciTests.vm-smoke"
  ;;

smoke-homeserver)
  build_attrs ".#legacyPackages.${system}.ciTests.homeserver-vm-smoke"
  ;;

profile-test)
  build_profile_test "${target:?Usage: $0 profile-test <name>}"
  ;;

profile-tests)
  build_attrs \
    ".#legacyPackages.${system}.ciTests.profile-security" \
    ".#legacyPackages.${system}.ciTests.profile-observability" \
    ".#legacyPackages.${system}.ciTests.profile-hardening"
  ;;

heavy)
  build_attrs \
    ".#legacyPackages.${system}.ciTests.vm-smoke" \
    ".#legacyPackages.${system}.ciTests.homeserver-vm-smoke" \
    ".#legacyPackages.${system}.ciTests.profile-security" \
    ".#legacyPackages.${system}.ciTests.profile-observability" \
    ".#legacyPackages.${system}.ciTests.profile-hardening"
  ;;

cve-reports)
  show_report_attrs \
    ".#legacyPackages.${system}.ciReports.main" \
    ".#legacyPackages.${system}.ciReports.homeserver"
  ;;

"" | -h | --help | help)
  usage
  ;;

*)
  echo "Unknown command: $command" >&2
  echo >&2
  usage >&2
  exit 1
  ;;
esac
