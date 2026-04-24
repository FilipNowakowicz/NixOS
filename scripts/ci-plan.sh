#!/usr/bin/env bash
set -euo pipefail

repo_root="$(
  git rev-parse --show-toplevel 2>/dev/null || pwd
)"
cd "$repo_root"

event_name="${GITHUB_EVENT_NAME:-}"
base_sha="${BASE_SHA:-}"

host_core_change='^(\.github/workflows/nix\.yml|\.github/actions/setup-nix/|scripts/ci-plan\.sh|scripts/validate\.sh|flake\.nix|flake\.lock|modules/|lib/|home/)'
test_core_change='^(\.github/workflows/nix\.yml|\.github/actions/setup-nix/|scripts/ci-plan\.sh|scripts/validate\.sh|flake\.nix|flake\.lock|modules/|lib/|home/|tests/nixos/)'
closure_change='^(\.github/workflows/nix\.yml|\.github/actions/setup-nix/|scripts/ci-plan\.sh|scripts/closure-diff\.sh|flake\.nix|flake\.lock|modules/|lib/|home/)'
main_change='^hosts/main/'
vm_change='^hosts/vm/'
homeserver_change='^hosts/homeserver/'
homeserver_vm_change='^hosts/homeserver-vm/'

main_ci=false
vm=false
homeserver=false
homeserver_vm=false
profile_tests=false
vm_smoke=false
homeserver_smoke=false
closure_main=false
closure_homeserver=false

changed_files=""
if [[ $event_name == "pull_request" ]]; then
  if [[ -z $base_sha ]] || ! git cat-file -e "$base_sha^{commit}" 2>/dev/null; then
    base_sha="$(git rev-list --max-parents=0 HEAD | tail -n 1)"
  fi
  changed_files="$(git diff --name-only "$base_sha" HEAD)"
else
  main_ci=true
  vm=true
  homeserver=true
  homeserver_vm=true
  profile_tests=true
  vm_smoke=true
  homeserver_smoke=true
  closure_main=true
  closure_homeserver=true
fi

if [[ -n $changed_files ]]; then
  if grep -qE "${host_core_change}|${main_change}" <<<"$changed_files"; then
    main_ci=true
  fi

  if grep -qE "${host_core_change}|${vm_change}" <<<"$changed_files"; then
    vm=true
  fi

  if grep -qE "${host_core_change}|${homeserver_change}" <<<"$changed_files"; then
    homeserver=true
  fi

  if grep -qE "${host_core_change}|${homeserver_vm_change}" <<<"$changed_files"; then
    homeserver_vm=true
  fi

  if grep -qE "${test_core_change}|${vm_change}" <<<"$changed_files"; then
    vm_smoke=true
  fi

  if grep -qE "${test_core_change}|${homeserver_change}|${homeserver_vm_change}" <<<"$changed_files"; then
    homeserver_smoke=true
  fi

  if grep -qE "${test_core_change}" <<<"$changed_files"; then
    profile_tests=true
  fi

  if grep -qE "${closure_change}|${main_change}" <<<"$changed_files"; then
    closure_main=true
  fi

  if grep -qE "${closure_change}|${homeserver_change}" <<<"$changed_files"; then
    closure_homeserver=true
  fi
fi

emit_bool() {
  local name=$1
  local value=$2
  echo "$name=$value" >>"$GITHUB_OUTPUT"
}

hosts_matrix='{"include":['
sep=""
if [[ $main_ci == "true" ]]; then
  hosts_matrix+='{"name":"main-ci"}'
  sep=","
fi
if [[ $vm == "true" ]]; then
  hosts_matrix+="${sep}"'{"name":"vm"}'
  sep=","
fi
if [[ $homeserver == "true" ]]; then
  hosts_matrix+="${sep}"'{"name":"homeserver"}'
  sep=","
fi
if [[ $homeserver_vm == "true" ]]; then
  hosts_matrix+="${sep}"'{"name":"homeserver-vm"}'
fi
hosts_matrix+=']}'

tests_matrix='{"include":['
sep=""
if [[ $vm_smoke == "true" ]]; then
  tests_matrix+='{"name":"vm-smoke","command":"smoke-vm","target":""}'
  sep=","
fi
if [[ $homeserver_smoke == "true" ]]; then
  tests_matrix+="${sep}"'{"name":"homeserver-vm-smoke","command":"smoke-homeserver","target":""}'
  sep=","
fi
if [[ $profile_tests == "true" ]]; then
  for profile in profile-security profile-observability profile-hardening; do
    tests_matrix+="${sep}"'{"name":"'"$profile"'","command":"profile-test","target":"'"$profile"'"}'
    sep=","
  done
fi
tests_matrix+=']}'

if [[ $main_ci == "true" || $vm == "true" || $homeserver == "true" || $homeserver_vm == "true" ]]; then
  emit_bool hosts true
else
  emit_bool hosts false
fi

if [[ $vm_smoke == "true" || $homeserver_smoke == "true" || $profile_tests == "true" ]]; then
  emit_bool tests true
else
  emit_bool tests false
fi

if [[ $closure_main == "true" || $closure_homeserver == "true" ]]; then
  emit_bool closure true
else
  emit_bool closure false
fi

emit_bool closure_main "$closure_main"
emit_bool closure_homeserver "$closure_homeserver"

{
  echo "hosts_matrix<<EOF"
  echo "$hosts_matrix"
  echo "EOF"
  echo "tests_matrix<<EOF"
  echo "$tests_matrix"
  echo "EOF"
} >>"$GITHUB_OUTPUT"

echo "Selected hosts: $hosts_matrix"
echo "Selected tests: $tests_matrix"
echo "Closure selectors: main=$closure_main homeserver=$closure_homeserver"
