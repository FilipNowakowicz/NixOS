#!/usr/bin/env bash
# Deploy or update the homeserver-gcp GCE infrastructure.
#
# Usage:
#   bash scripts/deploy-gcp.sh             # plan + apply
#   bash scripts/deploy-gcp.sh -auto-approve
#   bash scripts/deploy-gcp.sh -destroy
#
# Requirements: run inside `nix develop` (provides sops, opentofu, gcloud).
# Before first run: copy infra/terraform.tfvars.example to infra/terraform.tfvars
# and fill in your GCP project ID.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "==> Building NixOS GCE image..."
nix build '.#packages.x86_64-linux.homeserver-gcp-image' --out-link result-gcp-image

IMAGE_FILE=$(find -L result-gcp-image -name "*.raw.tar.gz" | head -1)
if [ -z "$IMAGE_FILE" ]; then
  echo "error: no *.raw.tar.gz found under result-gcp-image" >&2
  exit 1
fi
IMAGE_PATH=$(realpath "$IMAGE_FILE")
IMAGE_VERSION=$(date -u +%Y%m%d%H%M%S)

echo "==> Image: $IMAGE_PATH"

echo "==> Decrypting SSH host key..."
SSH_HOST_KEY_B64=$(
  sops --decrypt --input-type binary --output-type binary \
    hosts/homeserver-gcp/secrets/ssh_host_ed25519_key.enc |
    base64 -w0
)

echo "==> Initialising OpenTofu..."
cd infra
tofu init -upgrade

echo "==> Applying infrastructure..."
tofu apply \
  -var "image_path=${IMAGE_PATH}" \
  -var "image_version=${IMAGE_VERSION}" \
  -var "ssh_host_key_b64=${SSH_HOST_KEY_B64}" \
  "$@"

echo ""
echo "Done. Next steps:"
echo "  1. Wait ~60s for first boot (sops activation + Tailscale join)"
echo "  2. Confirm VM is on the tailnet: tailscale status | grep homeserver-gcp"
echo "  3. Remove bootstrap key from metadata:"
echo "     $(tofu output -raw ssh_host_key_removal_cmd 2>/dev/null || echo 'tofu output ssh_host_key_removal_cmd')"
echo "  4. Fill in real secrets: sops ../hosts/homeserver-gcp/secrets/secrets.yaml"
echo "  5. Deploy config: deploy '.#homeserver-gcp'"
