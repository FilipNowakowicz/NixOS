set -euo pipefail

# Clear stale SSH host key for the VM
"$SSH_KEYGEN_BIN" -R '[localhost]:2222'

# Temp dir for injected host keys; cleaned up on exit
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

mkdir -p "$tmpdir/etc/ssh"

# Decrypt host keys from sops-encrypted secrets
"$SOPS_BIN" --decrypt hosts/vm/secrets/ssh_host_ed25519_key.enc \
  > "$tmpdir/etc/ssh/ssh_host_ed25519_key"
"$SOPS_BIN" --decrypt hosts/vm/secrets/ssh_host_ed25519_key.pub.enc \
  > "$tmpdir/etc/ssh/ssh_host_ed25519_key.pub"

chmod 600 "$tmpdir/etc/ssh/ssh_host_ed25519_key"

# Install — inject host keys so the age identity is stable from first boot
"$NIXOS_ANYWHERE_BIN" \
  --flake '.#vm' \
  --extra-files "$tmpdir" \
  --no-substitute-on-destination \
  root@nixvm
