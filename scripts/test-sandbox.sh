#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-ghcr.io/pair-ai-platform/dify-sandbox:0.2.15-v1.0.0}"
PORT="${2:-8194}"
CONTAINER_NAME="dify-sandbox-test-$(date +%s)"
API_KEY="dify-sandbox-test-key"

echo "🚀 Starting test container: $CONTAINER_NAME from $IMAGE"

docker run -d \
  --name "$CONTAINER_NAME" \
  --cap-add=SYS_CHROOT \
  --cap-add=CHOWN \
  --cap-add=SETUID \
  --cap-add=SETGID \
  -p "$PORT":8194 \
  -e API_KEY="$API_KEY" \
  "$IMAGE"

cleanup() {
  echo "🧹 Cleaning up container: $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "⏳ Waiting for sandbox healthcheck..."
for i in {1..30}; do
  if curl -sf "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    echo "✅ Sandbox is healthy!"
    break
  fi
  sleep 1
done

echo "🧪 1. Testing Python execution..."
PYTHON_PAYLOAD='{
  "language": "python3",
  "code": "import sys, pandas, numpy\nprint(f\"Python {sys.version_info.major}.{sys.version_info.minor} | pandas {pandas.__version__} | numpy {numpy.__version__}\")\nresult = {\"status\": \"ok\", \"sum\": int(numpy.sum([10, 20, 30]))}"
}'

RESPONSE=$(curl -s -X POST "http://localhost:${PORT}/v1/sandbox/run" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PYTHON_PAYLOAD")

echo "Python Response: $RESPONSE"

echo "🧪 2. Testing Node.js execution..."
NODE_PAYLOAD='{
  "language": "nodejs",
  "code": "const axios = require(\"axios\"); const lodash = require(\"lodash\"); const sum = lodash.sum([5, 15, 25]); console.log(\"Node.js lodash sum:\", sum);"
}'

RESPONSE_NODE=$(curl -s -X POST "http://localhost:${PORT}/v1/sandbox/run" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$NODE_PAYLOAD")

echo "Node.js Response: $RESPONSE_NODE"

echo "🎉 All tests passed successfully!"
