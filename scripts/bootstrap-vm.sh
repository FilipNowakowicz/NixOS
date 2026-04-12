#!/usr/bin/env bash
set -euo pipefail

QCOW2_IMAGE="/vmstore/images/nixos-test.qcow2"
OVMF_VARS="/vmstore/images/nixos-test-vars.fd"
OVMF_SOURCE="/usr/share/OVMF/x64/OVMF_VARS.4m.fd"

# Create disk image if it doesn't exist
if [ ! -f "$QCOW2_IMAGE" ]; then
  echo "Creating VM disk image: $QCOW2_IMAGE"
  qemu-img create -f qcow2 "$QCOW2_IMAGE" 40G
else
  echo "VM disk image already exists: $QCOW2_IMAGE"
fi

# Copy OVMF vars if they don't exist
if [ ! -f "$OVMF_VARS" ]; then
  if [ ! -f "$OVMF_SOURCE" ]; then
    echo "Error: OVMF source not found at $OVMF_SOURCE"
    exit 1
  fi
  echo "Copying OVMF vars: $OVMF_SOURCE -> $OVMF_VARS"
  cp "$OVMF_SOURCE" "$OVMF_VARS"
else
  echo "OVMF vars already exist: $OVMF_VARS"
fi

echo "VM bootstrap complete"
