#!/usr/bin/env bash
# Offline smoke: CLI wiring (no browser required for help/version/mcp print).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BH="${ROOT}/bin/bh-clone"

echo "== version =="
"${BH}" version | grep -qE 'bh-chrome-clone 0\.2'

echo "== help =="
"${BH}" help | grep -q 'chrome-devtools'
"${BH}" help | grep -q 'browser-harness'

echo "== mcp print =="
out="$("${BH}" mcp print)"
echo "${out}" | grep -q 'browserUrl'
echo "${out}" | grep -q '127.0.0.1:9333'
# args block must not pass --auto-connect (comments may mention it)
if echo "${out}" | grep -v '^#' | grep -q -- '--auto-connect'; then
  echo "mcp print args must not use --auto-connect" >&2
  exit 1
fi

echo "== mcp json =="
"${BH}" mcp json | grep -q 'chrome-devtools'

echo "== unknown command fails =="
if "${BH}" not-a-command 2>/dev/null; then
  echo "expected failure" >&2
  exit 1
fi

echo "SMOKE_CLI_OK"
