#!/usr/bin/env bash
set -euo pipefail

repo_root="$(
  git rev-parse --show-toplevel 2>/dev/null || pwd
)"
cd "$repo_root"

event_name="${GITHUB_EVENT_NAME:-}"
base_sha="${BASE_SHA:-}"

ci_core_change='^(\.github/workflows/nix\.yml|\.github/actions/setup-nix/|scripts/ci-plan\.sh|scripts/validate\.sh)'
flake_or_lib_change='^(flake\.nix|flake\.lock|lib/)'
closure_script_change='^(scripts/closure-diff\.sh|\.github/scripts/upsert-closure-comment\.js)'
tests_change='^tests/nixos/'
main_change='^hosts/main/'
vm_change='^hosts/vm/'
homeserver_change='^hosts/homeserver/'
homeserver_vm_change='^hosts/homeserver-vm/'

module_all_hosts='^modules/nixos/(default\.nix|services/|profiles/(base|backup|security|sops-base|user)\.nix)'
module_desktop_hosts='^modules/nixos/(profiles/(desktop|observability-client)\.nix|hardware/nvidia-prime\.nix)'
module_server_hosts='^modules/nixos/profiles/observability/'
module_machine_hosts='^modules/nixos/profiles/(impermanence-base|machine-common)\.nix'
module_vm_host='^modules/nixos/profiles/vm\.nix'
module_microvm_guest='^modules/nixos/profiles/microvm-guest\.nix'
module_microvm_host='^modules/nixos/microvms/homeserver-vm\.nix'

home_all_hosts='^home/(profiles/base\.nix|users/user/common\.nix|files/nvim/)'
home_desktop_hosts='^home/(profiles/(desktop|workstation)\.nix|profiles/workflow-packs/|users/user/home\.nix|theme/|files/(firefox|hypr|kitty|waybar|scripts/(theme-switch|waybar-weather|clipboard-pick)\.sh))'
home_server_hosts='^home/users/user/server\.nix'
home_wsl='^home/users/user/wsl\.nix'

main_ci=false
vm=false
homeserver=false
homeserver_vm=false
profile_tests=false
vm_smoke=false
homeserver_smoke=false
closure_main=false
closure_homeserver=false

select_all_hosts() {
  main_ci=true
  vm=true
  homeserver=true
  homeserver_vm=true
  closure_main=true
  closure_homeserver=true
}

select_all_tests() {
  profile_tests=true
  vm_smoke=true
  homeserver_smoke=true
}

select_desktop_hosts() {
  main_ci=true
  vm=true
  closure_main=true
}

select_server_hosts() {
  homeserver=true
  homeserver_vm=true
  closure_homeserver=true
}

changed_files="${CI_CHANGED_FILES:-}"
if [[ $event_name == "pull_request" ]]; then
  if [[ -z $changed_files ]]; then
    if [[ -z $base_sha ]] || ! git cat-file -e "$base_sha^{commit}" 2>/dev/null; then
      base_sha="$(git rev-list --max-parents=0 HEAD | tail -n 1)"
    fi
    changed_files="$(git diff --name-only "$base_sha" HEAD)"
  fi
else
  select_all_hosts
  select_all_tests
fi

if [[ -n $changed_files ]]; then
  unknown_module_changed=false
  unknown_home_changed=false

  while IFS= read -r path; do
    if
      [[ $path =~ ^modules/nixos/ ]] &&
        ! grep -qE "${module_all_hosts}|${module_desktop_hosts}|${module_server_hosts}|${module_machine_hosts}|${module_vm_host}|${module_microvm_guest}|${module_microvm_host}" <<<"$path"
    then
      unknown_module_changed=true
    fi

    if
      [[ $path =~ ^home/ ]] &&
        ! grep -qE "${home_all_hosts}|${home_desktop_hosts}|${home_server_hosts}|${home_wsl}" <<<"$path"
    then
      unknown_home_changed=true
    fi
  done <<<"$changed_files"

  if grep -qE "${ci_core_change}|${flake_or_lib_change}" <<<"$changed_files"; then
    select_all_hosts
    select_all_tests
  fi

  if grep -qE "${tests_change}" <<<"$changed_files"; then
    select_all_tests
  fi

  if grep -qE "${closure_script_change}" <<<"$changed_files"; then
    closure_main=true
    closure_homeserver=true
  fi

  if grep -qE "${main_change}" <<<"$changed_files"; then
    main_ci=true
    closure_main=true
  fi

  if grep -qE "${vm_change}" <<<"$changed_files"; then
    vm=true
    vm_smoke=true
  fi

  if grep -qE "${homeserver_change}" <<<"$changed_files"; then
    homeserver=true
    closure_homeserver=true
    homeserver_smoke=true
  fi

  if grep -qE "${homeserver_vm_change}" <<<"$changed_files"; then
    homeserver_vm=true
    homeserver_smoke=true
  fi

  if grep -qE "${module_all_hosts}" <<<"$changed_files"; then
    select_all_hosts
    select_all_tests
  fi

  if grep -qE "${module_desktop_hosts}" <<<"$changed_files"; then
    select_desktop_hosts
    vm_smoke=true
    profile_tests=true
  fi

  if grep -qE "${module_server_hosts}" <<<"$changed_files"; then
    select_server_hosts
    homeserver_smoke=true
    profile_tests=true
  fi

  if grep -qE "${module_machine_hosts}" <<<"$changed_files"; then
    vm=true
    select_server_hosts
    vm_smoke=true
    homeserver_smoke=true
  fi

  if grep -qE "${module_vm_host}" <<<"$changed_files"; then
    vm=true
    vm_smoke=true
  fi

  if grep -qE "${module_microvm_guest}" <<<"$changed_files"; then
    homeserver_vm=true
    homeserver_smoke=true
  fi

  if grep -qE "${module_microvm_host}" <<<"$changed_files"; then
    main_ci=true
    homeserver_vm=true
    closure_main=true
    homeserver_smoke=true
  fi

  if [[ $unknown_module_changed == "true" ]]; then
    select_all_hosts
    select_all_tests
  fi

  if grep -qE "${home_all_hosts}" <<<"$changed_files"; then
    select_all_hosts
  fi

  if grep -qE "${home_desktop_hosts}" <<<"$changed_files"; then
    select_desktop_hosts
  fi

  if grep -qE "${home_server_hosts}" <<<"$changed_files"; then
    select_server_hosts
  fi

  if [[ $unknown_home_changed == "true" ]]; then
    select_all_hosts
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
  hosts_matrix+="${sep}"'{"name":"vm-ci"}'
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
