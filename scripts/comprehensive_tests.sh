#!/usr/bin/env bash
set -eo pipefail

PORT="${1:-8194}"
API_KEY="${2:-dify-sandbox-ci-test-key}"
BASE_URL="http://localhost:${PORT}"

echo "============================================================"
echo "🚀 Running Dify Sandbox Comprehensive Verification Test Suite"
echo "   Endpoint: $BASE_URL"
echo "============================================================"

PASSED=0
FAILED=0

run_test() {
  local name="$1"
  local lang="$2"
  local code="$3"
  local expected_keyword="$4"
  local expect_error="${5:-false}"

  echo -n "👉 Test: [$lang] $name ... "

  local payload
  payload=$(jq -n \
    --arg lang "$lang" \
    --arg code "$code" \
    '{language: $lang, code: $code, preload: "", enable_network: true}')

  local res
  res=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/v1/sandbox/run" \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $API_KEY" \
    -d "$payload" || true)

  local http_code
  http_code=$(echo "$res" | tail -n1)
  local body
  body=$(echo "$res" | sed '$d')

  if [ "$http_code" != "200" ]; then
    echo "❌ FAILED (HTTP $http_code)"
    echo "   Response: $body"
    FAILED=$((FAILED + 1))
    return
  fi

  if [ "$expect_error" = "true" ]; then
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
  'import os; print("RUNNER_UID:" + str(os.getuid()))' \
  "RUNNER_UID:"

run_test "Python Scientific Stack (NumPy & Pandas)" "python3" \
  'import numpy as np, pandas as pd; df = pd.DataFrame({"a": [1, 2], "b": [3, 4]}); print("SUM:" + str(df.to_numpy().sum()))' \
  "SUM:10"

run_test "Python LLM Tokenizer (Tiktoken)" "python3" \
  'import tiktoken; enc = tiktoken.get_encoding("cl100k_base"); print("TOKENS:" + str(len(enc.encode("Hello World"))))' \
  "TOKENS:2"

run_test "Python HTTP & Jinja2 Template" "python3" \
  'import jinja2, requests; t = jinja2.Template("Hello {{ name }}!"); print(t.render(name="World"))' \
  "Hello World!"

run_test "Python Cryptography Security" "python3" \
  'from cryptography.fernet import Fernet; key = Fernet.generate_key(); f = Fernet(key); token = f.encrypt(b"secret message"); print("FERNET_DECRYPT:" + f.decrypt(token).decode())' \
  "FERNET_DECRYPT:secret message"

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
