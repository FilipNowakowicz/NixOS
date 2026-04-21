#!/usr/bin/env bash
# Unified VM management script.
# All VM infrastructure is derived from the VM_REGISTRY JSON env var
# (set by the Nix wrapper in flake.nix).
#
# Usage: nix run '.#vm' -- <action> <name>
#   create <name>     Full setup: disk + OVMF + ISO boot + nixos-anywhere + start
#   start <name>      Launch existing VM
#   stop <name>       Graceful shutdown, falls back to SIGTERM
#   reinstall <name>  Stop + wipe root + reinstall + start
#   destroy <name>    Stop + delete all VM artifacts + remove SSH config
#   ssh <name>        SSH into the VM
#   list              Show all registered VMs with status
#   init <name>       Generate SSH host key + sops secrets scaffold for a new VM
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
VM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nixos-vms"
SSH_CONFIG="$HOME/.ssh/config"
SSH_WAIT_TIMEOUT=120
SSH_WAIT_INTERVAL=3

# ── Required env (set by Nix wrapper) ────────────────────────────────────────
: "${VM_REGISTRY:?VM_REGISTRY not set — run via nix run .#vm}"
: "${OVMF_CODE:?OVMF_CODE not set — run via nix run .#vm}"
: "${OVMF_SOURCE:?OVMF_SOURCE not set — run via nix run .#vm}"
: "${QEMU_BIN:?QEMU_BIN not set — run via nix run .#vm}"
: "${QEMU_IMG_BIN:?QEMU_IMG_BIN not set — run via nix run .#vm}"
: "${JQ_BIN:?JQ_BIN not set — run via nix run .#vm}"
: "${SSH_KEYGEN_BIN:?SSH_KEYGEN_BIN not set — run via nix run .#vm}"

# Optional — only needed for create/reinstall/init
NIXOS_ANYWHERE_BIN="${NIXOS_ANYWHERE_BIN:-}"
SOPS_BIN="${SOPS_BIN:-}"
SSH_TO_AGE_BIN="${SSH_TO_AGE_BIN:-}"

# ── Helpers ──────────────────────────────────────────────────────────────────
die() {
  echo "error: $*" >&2
  exit 1
}

vm_attr() {
  local name="$1" attr="$2"
  "$JQ_BIN" -r --arg n "$name" --arg a "$attr" '.[$n][$a] // empty' <<<"$VM_REGISTRY"
}

vm_exists_in_registry() {
  "$JQ_BIN" -e --arg n "$1" 'has($n)' <<<"$VM_REGISTRY" >/dev/null 2>&1
}

all_vm_names() {
  "$JQ_BIN" -r 'keys[]' <<<"$VM_REGISTRY"
}

vm_disk() { echo "$VM_DIR/$1.qcow2"; }
vm_vars() { echo "$VM_DIR/$1-vars.fd"; }
vm_pidfile() { echo "$VM_DIR/$1.pid"; }

vm_is_running() {
  local pidfile
  pidfile="$(vm_pidfile "$1")"
  [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

vm_is_created() {
  [ -f "$(vm_disk "$1")" ]
}

require_vm() {
  vm_exists_in_registry "$1" || die "unknown VM '$1' — not in lib/hosts.nix"
}

require_created() {
  vm_is_created "$1" || die "VM '$1' has no disk image — run: nix run '.#vm' -- create $1"
}

require_tools() {
  for tool in "$@"; do
    local var="${tool}"
    [ -n "${!var:-}" ] || die "$var not set — this action requires it"
  done
}

# ── SSH config management ────────────────────────────────────────────────────
ssh_config_add() {
  local name="$1" port="$2"
  mkdir -p "$(dirname "$SSH_CONFIG")"
  touch "$SSH_CONFIG"

  if grep -q "^Host ${name}$" "$SSH_CONFIG" 2>/dev/null; then
    echo "SSH config for $name already exists"
    return
  fi

  cat >>"$SSH_CONFIG" <<EOF

Host ${name}
    HostName localhost
    Port ${port}
    User user
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
  echo "Added SSH config: $name → localhost:$port"
}

ssh_config_remove() {
  local name="$1"
  if [ ! -f "$SSH_CONFIG" ]; then return; fi
  # Remove the Host block (Host line + indented lines following it)
  sed -i "/^Host ${name}$/,/^$/d" "$SSH_CONFIG"
  # Clean up any trailing blank lines
  sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$SSH_CONFIG"
  echo "Removed SSH config for $name"
}

ssh_clear_known_hosts() {
  local name="$1" port="$2"
  "$SSH_KEYGEN_BIN" -R "[localhost]:${port}" 2>/dev/null || true
}

# ── SSH wait ─────────────────────────────────────────────────────────────────
wait_for_ssh() {
  local name="$1" port="$2" ssh_user="$3"
  local elapsed=0

  echo "Waiting for SSH on localhost:${port}..."
  while [ "$elapsed" -lt "$SSH_WAIT_TIMEOUT" ]; do
    if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -p "$port" "${ssh_user}@localhost" true 2>/dev/null; then
      echo "SSH is ready"
      return 0
    fi
    sleep "$SSH_WAIT_INTERVAL"
    elapsed=$((elapsed + SSH_WAIT_INTERVAL))
    echo "  waiting... (${elapsed}s/${SSH_WAIT_TIMEOUT}s)"
  done

  die "SSH not ready after ${SSH_WAIT_TIMEOUT}s — is the VM booting?"
}

# ── QEMU launch ──────────────────────────────────────────────────────────────
qemu_launch() {
  local name="$1" port="$2"
  shift 2
  # Remaining args are extra QEMU flags (e.g. -cdrom, -boot)

  "$QEMU_BIN" -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$(vm_vars "$name")" \
    -drive file="$(vm_disk "$name")",if=virtio \
    -netdev user,id=net0,hostfwd=tcp::"${port}"-:22 \
    -device virtio-net-pci,netdev=net0 \
    -pidfile "$(vm_pidfile "$name")" \
    -daemonize -display none \
    "$@"
}

# ── Actions ──────────────────────────────────────────────────────────────────

action_create() {
  local name="$1"
  local port disk_size

  port="$(vm_attr "$name" sshPort)"
  disk_size="$(vm_attr "$name" diskSize)"

  if vm_is_created "$name"; then
    die "VM '$name' already exists — use 'reinstall' to wipe, or 'destroy' first"
  fi

  # Check that encrypted host keys exist
  local secrets_dir="hosts/${name}/secrets"
  if [ ! -f "${secrets_dir}/ssh_host_ed25519_key.enc" ]; then
    die "No encrypted host keys in ${secrets_dir}/ — run: nix run '.#vm' -- init ${name}"
  fi

  require_tools NIXOS_ANYWHERE_BIN SOPS_BIN

  mkdir -p "$VM_DIR"

  # 1. Create disk image
  echo "Creating disk image: $(vm_disk "$name") (${disk_size})"
  "$QEMU_IMG_BIN" create -f qcow2 "$(vm_disk "$name")" "$disk_size"

  # 2. Copy OVMF vars (must be writable for QEMU EFI boot state)
  echo "Initializing OVMF vars"
  cp "$OVMF_SOURCE" "$(vm_vars "$name")"
  chmod +w "$(vm_vars "$name")"

  # 3. Add SSH config
  ssh_config_add "$name" "$port"
  ssh_clear_known_hosts "$name" "$port"

  # 4. Build installer ISO
  echo "Building installer ISO..."
  local iso_path
  iso_path="$(nix build '.#installer-iso' --no-link --print-out-paths)/iso"
  local iso_file
  iso_file="$(ls "$iso_path"/*.iso)"
  echo "ISO: $iso_file"

  # 5. Boot ISO
  echo "Booting installer ISO..."
  qemu_launch "$name" "$port" -cdrom "$iso_file" -boot order=d

  # 6. Wait for SSH
  wait_for_ssh "$name" "$port" root

  # 7. Run nixos-anywhere
  echo "Installing NixOS via nixos-anywhere..."
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  mkdir -p "$tmpdir/persist/etc/ssh"
  "$SOPS_BIN" --decrypt "${secrets_dir}/ssh_host_ed25519_key.enc" \
    >"$tmpdir/persist/etc/ssh/ssh_host_ed25519_key"
  "$SOPS_BIN" --decrypt "${secrets_dir}/ssh_host_ed25519_key.pub.enc" \
    >"$tmpdir/persist/etc/ssh/ssh_host_ed25519_key.pub"
  chmod 600 "$tmpdir/persist/etc/ssh/ssh_host_ed25519_key"

  "$NIXOS_ANYWHERE_BIN" \
    --flake ".#${name}" \
    --extra-files "$tmpdir" \
    --ssh-port "$port" \
    --ssh-option StrictHostKeyChecking=no \
    --ssh-option UserKnownHostsFile=/dev/null \
    "root@localhost"

  # 8. Stop ISO VM (nixos-anywhere may have already shut it down)
  echo "Stopping installer..."
  action_stop "$name" 2>/dev/null || true
  sleep 2

  # 9. Boot installed VM
  ssh_clear_known_hosts "$name" "$port"
  echo "Starting installed VM..."
  qemu_launch "$name" "$port"
  wait_for_ssh "$name" "$port" user

  echo ""
  echo "✓ VM '$name' is ready"
  echo "  SSH:    ssh $name"
  echo "  Deploy: deploy .#$name"
}

action_start() {
  local name="$1"
  local port

  require_created "$name"
  port="$(vm_attr "$name" sshPort)"

  if vm_is_running "$name"; then
    echo "VM '$name' is already running"
    return 0
  fi

  # Ensure SSH config exists
  ssh_config_add "$name" "$port"

  echo "Starting VM '$name' on port $port..."
  qemu_launch "$name" "$port"
  echo "VM '$name' started (PID: $(cat "$(vm_pidfile "$name")"))"
}

action_stop() {
  local name="$1"

  if ! vm_is_running "$name"; then
    echo "VM '$name' is not running"
    # Clean up stale pidfile
    rm -f "$(vm_pidfile "$name")"
    return 0
  fi

  local pid
  pid="$(cat "$(vm_pidfile "$name")")"
  echo "Stopping VM '$name' (PID: $pid)..."

  # Try graceful shutdown via SSH first
  local port
  port="$(vm_attr "$name" sshPort)"
  if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -p "$port" user@localhost sudo poweroff 2>/dev/null; then
    # Wait for process to exit
    local i=0
    while [ "$i" -lt 15 ] && kill -0 "$pid" 2>/dev/null; do
      sleep 1
      i=$((i + 1))
    done
  fi

  # Force kill if still running
  if kill -0 "$pid" 2>/dev/null; then
    echo "Graceful shutdown timed out, sending SIGTERM..."
    kill "$pid" 2>/dev/null || true
    sleep 2
  fi

  rm -f "$(vm_pidfile "$name")"
  echo "VM '$name' stopped"
}

action_reinstall() {
  local name="$1"
  local port

  port="$(vm_attr "$name" sshPort)"

  local secrets_dir="hosts/${name}/secrets"
  if [ ! -f "${secrets_dir}/ssh_host_ed25519_key.enc" ]; then
    die "No encrypted host keys in ${secrets_dir}/"
  fi

  require_tools NIXOS_ANYWHERE_BIN SOPS_BIN

  # Stop if running
  action_stop "$name" 2>/dev/null || true
  sleep 1

  # Check disk exists — if not, redirect to create
  if ! vm_is_created "$name"; then
    echo "No disk image found — running full create instead"
    action_create "$name"
    return
  fi

  ssh_clear_known_hosts "$name" "$port"

  # Build installer ISO
  echo "Building installer ISO..."
  local iso_path
  iso_path="$(nix build '.#installer-iso' --no-link --print-out-paths)/iso"
  local iso_file
  iso_file="$(ls "$iso_path"/*.iso)"

  # Boot ISO
  echo "Booting installer ISO..."
  qemu_launch "$name" "$port" -cdrom "$iso_file" -boot order=d

  # Wait for SSH
  wait_for_ssh "$name" "$port" root

  # Run nixos-anywhere
  echo "Reinstalling NixOS via nixos-anywhere..."
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  mkdir -p "$tmpdir/persist/etc/ssh"
  "$SOPS_BIN" --decrypt "${secrets_dir}/ssh_host_ed25519_key.enc" \
    >"$tmpdir/persist/etc/ssh/ssh_host_ed25519_key"
  "$SOPS_BIN" --decrypt "${secrets_dir}/ssh_host_ed25519_key.pub.enc" \
    >"$tmpdir/persist/etc/ssh/ssh_host_ed25519_key.pub"
  chmod 600 "$tmpdir/persist/etc/ssh/ssh_host_ed25519_key"

  "$NIXOS_ANYWHERE_BIN" \
    --flake ".#${name}" \
    --extra-files "$tmpdir" \
    --ssh-port "$port" \
    --ssh-option StrictHostKeyChecking=no \
    --ssh-option UserKnownHostsFile=/dev/null \
    "root@localhost"

  # Stop ISO VM
  action_stop "$name" 2>/dev/null || true
  sleep 2

  # Boot installed VM
  ssh_clear_known_hosts "$name" "$port"
  echo "Starting reinstalled VM..."
  qemu_launch "$name" "$port"
  wait_for_ssh "$name" "$port" user

  echo ""
  echo "✓ VM '$name' reinstalled and ready"
}

action_destroy() {
  local name="$1"

  # Stop if running
  action_stop "$name" 2>/dev/null || true

  local destroyed=false

  if [ -f "$(vm_disk "$name")" ]; then
    rm -f "$(vm_disk "$name")"
    echo "Deleted disk image"
    destroyed=true
  fi

  if [ -f "$(vm_vars "$name")" ]; then
    rm -f "$(vm_vars "$name")"
    echo "Deleted OVMF vars"
    destroyed=true
  fi

  rm -f "$(vm_pidfile "$name")"
  ssh_config_remove "$name"

  local port
  port="$(vm_attr "$name" sshPort)"
  ssh_clear_known_hosts "$name" "$port"

  if [ "$destroyed" = true ]; then
    echo "✓ VM '$name' destroyed"
  else
    echo "VM '$name' had no artifacts to clean up"
  fi
}

action_ssh() {
  local name="$1"
  local port
  port="$(vm_attr "$name" sshPort)"

  shift
  exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -p "$port" user@localhost "$@"
}

action_list() {
  printf "%-20s %-10s %s\n" "NAME" "STATUS" "PORT"
  printf "%-20s %-10s %s\n" "----" "------" "----"

  for name in $(all_vm_names); do
    local port status
    port="$(vm_attr "$name" sshPort)"

    if vm_is_running "$name"; then
      status="running"
    elif vm_is_created "$name"; then
      status="stopped"
    else
      status="not created"
    fi

    printf "%-20s %-10s %s\n" "$name" "$status" "$port"
  done
}

action_init() {
  local name="$1"
  local secrets_dir="hosts/${name}/secrets"

  require_tools SOPS_BIN SSH_TO_AGE_BIN

  # Check host config exists
  if [ ! -f "hosts/${name}/default.nix" ]; then
    die "No host config at hosts/${name}/default.nix — create it first"
  fi

  # Check if keys already exist
  if [ -f "${secrets_dir}/ssh_host_ed25519_key.enc" ]; then
    die "Host keys already exist in ${secrets_dir}/ — delete them first to regenerate"
  fi

  mkdir -p "$secrets_dir"

  # Generate SSH host key pair
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  "$SSH_KEYGEN_BIN" -t ed25519 -f "$tmpdir/ssh_host_ed25519_key" -N "" -q
  echo "Generated SSH host key pair"

  # Convert to age key
  local age_key
  age_key="$("$SSH_TO_AGE_BIN" <"$tmpdir/ssh_host_ed25519_key.pub")"
  echo "Age public key: $age_key"

  # Encrypt host keys with sops (user key only — host key will be added to .sops.yaml)
  "$SOPS_BIN" --encrypt --age "$(grep -oP 'public key: \K.*' ~/.config/sops/age/keys.txt 2>/dev/null || echo "$age_key")" \
    "$tmpdir/ssh_host_ed25519_key" >"${secrets_dir}/ssh_host_ed25519_key.enc"
  "$SOPS_BIN" --encrypt --age "$(grep -oP 'public key: \K.*' ~/.config/sops/age/keys.txt 2>/dev/null || echo "$age_key")" \
    "$tmpdir/ssh_host_ed25519_key.pub" >"${secrets_dir}/ssh_host_ed25519_key.pub.enc"
  echo "Encrypted host keys to ${secrets_dir}/"

  # Create secrets.yaml if it doesn't exist
  if [ ! -f "${secrets_dir}/secrets.yaml" ]; then
    echo "# Secrets for ${name} — edit with: sops ${secrets_dir}/secrets.yaml" >"$tmpdir/secrets_template.yaml"
    echo "user_password: ''" >>"$tmpdir/secrets_template.yaml"
    "$SOPS_BIN" --encrypt --age "$(grep -oP 'public key: \K.*' ~/.config/sops/age/keys.txt 2>/dev/null || echo "$age_key")" \
      "$tmpdir/secrets_template.yaml" >"${secrets_dir}/secrets.yaml"
    echo "Created ${secrets_dir}/secrets.yaml"
  fi

  echo ""
  echo "Next steps:"
  echo "  1. Add this to .sops.yaml under 'keys:':"
  echo "     - &${name//-/_}_host $age_key"
  echo ""
  echo "  2. Add a creation rule to .sops.yaml:"
  echo "     - path_regex: hosts/${name}/secrets/.*"
  echo "       key_groups:"
  echo "         - age:"
  echo "             - *user"
  echo "             - *${name//-/_}_host"
  echo ""
  echo "  3. Re-encrypt secrets with the new key:"
  echo "     sops updatekeys ${secrets_dir}/secrets.yaml"
  echo ""
  echo "  4. Edit secrets (set user_password):"
  echo "     sops ${secrets_dir}/secrets.yaml"
  echo ""
  echo "  5. Create the VM:"
  echo "     nix run '.#vm' -- create ${name}"
}

# ── Main ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: nix run '.#vm' -- <action> [name] [args...]

Actions:
  create <name>      Full setup: disk + install + boot
  start <name>       Launch existing VM
  stop <name>        Graceful shutdown
  reinstall <name>   Wipe and reinstall
  destroy <name>     Delete all VM artifacts
  ssh <name> [cmd]   SSH into the VM
  list               Show all VMs with status
  init <name>        Generate sops secrets for a new VM
EOF
  exit 1
}

action="${1:-}"
[ -n "$action" ] || usage

case "$action" in
list)
  action_list
  ;;
create | start | stop | reinstall | destroy | ssh | init)
  name="${2:-}"
  [ -n "$name" ] || die "missing VM name — usage: nix run '.#vm' -- $action <name>"
  require_vm "$name"
  shift 2
  "action_${action}" "$name" "$@"
  ;;
*)
  die "unknown action '$action'"
  ;;
esac
