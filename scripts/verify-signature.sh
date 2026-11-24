#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image-reference>"
  echo "Example: $0 ghcr.io/taha2samy-3/dify-sandbox:0.2.15-v1.0.0"
  exit 1
fi

if ! command -v cosign &>/dev/null; then
  echo "❌ Error: cosign is not installed. Please install cosign first:"
  echo "   https://docs.sigstore.dev/cosign/system_config/installation/"
  exit 1
fi

echo "🔍 Verifying signature for: $IMAGE"

# Verify Keyless Cosign signature created by GitHub Actions OIDC
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity-regexp "^https://github.com/taha2samy-3/.*" \
  "$IMAGE"

echo "✅ Signature verified successfully! Image authenticity is guaranteed."
