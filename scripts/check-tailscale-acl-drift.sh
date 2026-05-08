#!/usr/bin/env bash
set -euo pipefail

# Compares the rendered tailscale-acl package against the live Tailscale policy.
# Only the fields emitted by our generator (tagOwners, acls) are compared after
# key-sorting so formatting noise does not trigger false positives.
#
# Required env:
#   TAILSCALE_API_KEY   — Tailscale API key with policy:read scope
#   TAILSCALE_TAILNET   — Tailscale tailnet name (e.g. tail90fc7a.ts.net)

: "${TAILSCALE_API_KEY:?TAILSCALE_API_KEY must be set}"
: "${TAILSCALE_TAILNET:?TAILSCALE_TAILNET must be set}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

echo "Building rendered ACL artifact..."
acl_path="$(nix build '.#packages.x86_64-linux.tailscale-acl' --no-link --print-out-paths)"

echo "Fetching live Tailscale policy..."
live_json="$(
  curl -sf \
    --header "Authorization: Bearer ${TAILSCALE_API_KEY}" \
    --header "Accept: application/json" \
    "https://api.tailscale.com/api/v2/tailnet/${TAILSCALE_TAILNET}/acl"
)"

rendered_normal="$(jq -S '{tagOwners, acls}' "$acl_path")"
live_normal="$(printf '%s' "$live_json" | jq -S '{tagOwners, acls}')"

if diff --unified \
  --label "rendered (lib/acl.nix)" \
  <(printf '%s\n' "$rendered_normal") \
  --label "live (${TAILSCALE_TAILNET})" \
  <(printf '%s\n' "$live_normal"); then
  echo "ACL drift check passed: live policy matches rendered artifact."
else
  echo ""
  echo "ACL DRIFT DETECTED: update lib/acl.nix or apply the rendered ACL to Tailscale."
  exit 1
fi
