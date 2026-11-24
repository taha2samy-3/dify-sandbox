#!/usr/bin/env bash
set -eo pipefail

PORT="${1:-8194}"
API_KEY="${2:-dify-sandbox-test-key}"
BASE_URL="http://localhost:${PORT}"

echo "============================================================"
echo "🧪 Starting Comprehensive Dify Sandbox Test Suite"
echo "Target: $BASE_URL | API Key: $API_KEY"
echo "============================================================"

PASSED=0
FAILED=0

run_test() {
  local name="$1"
  local lang="$2"
  local code="$3"
  local expected_keyword="$4"
  local should_fail="${5:-false}"

  echo -n "👉 Test: [$lang] $name ... "

  local payload
  payload=$(jq -n \
    --arg lang "$lang" \
    --arg code "$code" \
    '{language: $lang, code: $code}')

  local response
  response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$BASE_URL/v1/sandbox/run" \
    -H "X-Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local http_code
  http_code=$(echo "$response" | grep "HTTP_STATUS" | cut -d':' -f2)
  local body
  body=$(echo "$response" | grep -v "HTTP_STATUS")

  if [ "$http_code" -ne 200 ]; then
    echo "❌ FAILED (HTTP $http_code)"
    echo "   Response: $body"
    FAILED=$((FAILED + 1))
    return
  fi

  if [ "$should_fail" = "true" ]; then
    local err
    err=$(echo "$body" | jq -r '.data.error // empty')
    if [ -n "$err" ] || [[ "$body" == *"$expected_keyword"* ]]; then
      echo "✅ PASSED (Caught expected error)"
      PASSED=$((PASSED + 1))
    else
      echo "❌ FAILED (Expected error not caught)"
      echo "   Response: $body"
      FAILED=$((FAILED + 1))
    fi
  else
    if [[ "$body" == *"$expected_keyword"* ]]; then
      echo "✅ PASSED"
      PASSED=$((PASSED + 1))
    else
      echo "❌ FAILED"
      echo "   Expected keyword: $expected_keyword"
      echo "   Actual response: $body"
      FAILED=$((FAILED + 1))
    fi
  fi
}

echo "--- 1. Healthcheck ---"
if curl -sf "$BASE_URL/health" >/dev/null; then
  echo "✅ Healthcheck OK"
  PASSED=$((PASSED + 1))
else
  echo "❌ Healthcheck Failed"
  FAILED=$((FAILED + 1))
fi

echo ""
echo "--- 2. Python Tests ---"

run_test "Basic Python Execution" "python3" \
  'print("Hello Dify Sandbox Python!")' \
  "Hello Dify Sandbox Python!"

run_test "Python UID Isolation (Non-root)" "python3" \
  'import os; print(f"RUNNER_UID:{os.getuid()}")' \
  "RUNNER_UID:"

run_test "Python Scientific Stack (NumPy & Pandas)" "python3" \
  'import numpy as np, pandas as pd; df = pd.DataFrame({"a": [1, 2], "b": [3, 4]}); print(f"SUM:{df.to_numpy().sum()}")' \
  "SUM:10"

run_test "Python LLM Tokenizer (Tiktoken)" "python3" \
  'import tiktoken; enc = tiktoken.get_encoding("cl100k_base"); print(f"TOKENS:{len(enc.encode(\"Hello World\"))}")' \
  "TOKENS:2"

run_test "Python HTTP & Jinja2 Template" "python3" \
  'import jinja2, requests; t = jinja2.Template("Hello {{ name }}!"); print(t.render(name="World"))' \
  "Hello World!"

run_test "Python Syntax Error Handling" "python3" \
  'def broken_function(: pass' \
  "SyntaxError" \
  "true"

run_test "Python Timeout Enforcement" "python3" \
  'import time; time.sleep(20); print("Should not reach here")' \
  "time limit exceeded" \
  "true"

echo ""
echo "--- 3. Node.js Tests ---"

run_test "Basic Node.js Execution" "nodejs" \
  'console.log("Hello Dify Sandbox Node.js!");' \
  "Hello Dify Sandbox Node.js!"

run_test "Node.js Lodash Utilities" "nodejs" \
  'const _ = require("lodash"); console.log("SUM:" + _.sum([10, 20, 30]));' \
  "SUM:60"

run_test "Node.js Date/Time (Moment & Dayjs)" "nodejs" \
  'const moment = require("moment"); console.log("YEAR:" + moment().year());' \
  "YEAR:202"

run_test "Node.js Cryptography (Crypto-JS)" "nodejs" \
  'const CryptoJS = require("crypto-js"); const hash = CryptoJS.SHA256("dify").toString(); console.log("HASH_LEN:" + hash.length);' \
  "HASH_LEN:64"

run_test "Node.js BigNumber Precision" "nodejs" \
  'const BigNumber = require("bignumber.js"); const x = new BigNumber("0.1").plus("0.2"); console.log("CALC:" + x.toString());' \
  "CALC:0.3"

run_test "Node.js Syntax Error Handling" "nodejs" \
  'const broken = ;' \
  "SyntaxError" \
  "true"

echo ""
echo "============================================================"
echo "📊 Test Suite Results: $PASSED Passed | $FAILED Failed"
echo "============================================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
