#!/usr/bin/env bash
set -euo pipefail

target_ip="${1:?Usage: reinstall-homeserver <target-ip>}"

# Temp dir for injected host keys; cleaned up on exit
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

mkdir -p "$tmpdir/etc/ssh"

# Decrypt host keys from sops-encrypted secrets
"$SOPS_BIN" --decrypt hosts/homeserver/secrets/ssh_host_ed25519_key.enc \
  > "$tmpdir/etc/ssh/ssh_host_ed25519_key"
"$SOPS_BIN" --decrypt hosts/homeserver/secrets/ssh_host_ed25519_key.pub.enc \
  > "$tmpdir/etc/ssh/ssh_host_ed25519_key.pub"

chmod 600 "$tmpdir/etc/ssh/ssh_host_ed25519_key"

# Install — inject host keys so the age identity is stable from first boot
"$NIXOS_ANYWHERE_BIN" \
  --flake '.#homeserver' \
  --extra-files "$tmpdir" \
  --no-substitute-on-destination \
  "root@${target_ip}"
