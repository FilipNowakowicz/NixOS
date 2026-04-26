#!/usr/bin/env bash
set -euo pipefail

SSH_KEYSCAN_BIN="${SSH_KEYSCAN_BIN:-ssh-keyscan}"
SSH_KEYGEN_BIN="${SSH_KEYGEN_BIN:-ssh-keygen}"

usage() {
  cat >&2 <<'EOF'
Usage: reinstall-homeserver <target-ip> --expected-fingerprint <SHA256:...>
       reinstall-homeserver <target-ip> --known-hosts <file>

Options:
  --expected-fingerprint <fp>   Verify the installer host key by fingerprint
                                (SHA256:... from the console or manual scan)
  --known-hosts <file>          Verify via a pre-populated known_hosts file

The installer generates a fresh ephemeral host key on each boot.
Obtain the fingerprint before running this script:

  ssh-keyscan -t ed25519 <target-ip> | ssh-keygen -lf /dev/stdin

Or read it from the installer's serial/video console.
EOF
  exit 1
}

target_ip="${1:?$(usage)}"
shift

expected_fp=""
known_hosts_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --expected-fingerprint)
    expected_fp="${2:?--expected-fingerprint requires a value}"
    shift 2
    ;;
  --known-hosts)
    known_hosts_file="${2:?--known-hosts requires a value}"
    shift 2
    ;;
  *)
    echo "error: unknown option: $1" >&2
    usage
    ;;
  esac
done

if [[ -z $expected_fp && -z $known_hosts_file ]]; then
  echo "error: host key verification is required — reinstall aborted" >&2
  echo "" >&2
  echo "The installer generates a fresh host key each boot." >&2
  echo "Obtain the fingerprint from the installer console or run:" >&2
  echo "  ssh-keyscan -t ed25519 ${target_ip} | ssh-keygen -lf /dev/stdin" >&2
  echo "" >&2
  echo "Then re-run with --expected-fingerprint <SHA256:...>" >&2
  exit 1
fi

# Temp dir for injected host keys and verified known_hosts; cleaned up on exit
tmpdir=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $tmpdir" EXIT

mkdir -p "$tmpdir/etc/ssh"

if [[ -n $expected_fp ]]; then
  echo "Scanning installer host key from ${target_ip}..." >&2
  scanned_key=$("$SSH_KEYSCAN_BIN" -t ed25519 "$target_ip" 2>/dev/null || true)

  if [[ -z $scanned_key ]]; then
    echo "error: no ed25519 host key found at ${target_ip}" >&2
    echo "Ensure the installer is booted and sshd is listening." >&2
    exit 1
  fi

  scanned_file="$tmpdir/scanned_known_hosts"
  printf '%s\n' "$scanned_key" >"$scanned_file"
  actual_fp=$("$SSH_KEYGEN_BIN" -lf "$scanned_file" | awk '{print $2}')

  if [[ $actual_fp != "$expected_fp" ]]; then
    echo "error: host key fingerprint mismatch — reinstall aborted" >&2
    echo "  expected: ${expected_fp}" >&2
    echo "  actual:   ${actual_fp}" >&2
    echo "" >&2
    echo "The installer may have rebooted and generated a new key." >&2
    echo "Re-obtain the fingerprint from the console before retrying." >&2
    exit 1
  fi

  echo "Host key verified: ${actual_fp}" >&2
  known_hosts_file="$scanned_file"
fi

if [[ ! -f $known_hosts_file ]]; then
  echo "error: known_hosts file not found: ${known_hosts_file}" >&2
  exit 1
fi

# Decrypt host keys from sops-encrypted secrets
"$SOPS_BIN" --decrypt hosts/homeserver/secrets/ssh_host_ed25519_key.enc \
  >"$tmpdir/etc/ssh/ssh_host_ed25519_key"
"$SOPS_BIN" --decrypt hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc \
  >"$tmpdir/etc/ssh/ssh_host_ed25519_key.pub"

chmod 600 "$tmpdir/etc/ssh/ssh_host_ed25519_key"

# Install — inject host keys so the age identity is stable from first boot.
# StrictHostKeyChecking=yes and UserKnownHostsFile ensure nixos-anywhere's
# SSH connections (including the rsync phase) are bound to the verified key.
"$NIXOS_ANYWHERE_BIN" \
  --flake '.#homeserver' \
  --extra-files "$tmpdir" \
  --no-substitute-on-destination \
  --ssh-option "StrictHostKeyChecking=yes" \
  --ssh-option "UserKnownHostsFile=${known_hosts_file}" \
  "root@${target_ip}"
