#!/usr/bin/env bash
# Offline smoke: CLI wiring only (no browser required for help/version).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BH="${ROOT}/bin/bh-clone"

echo "== version =="
"${BH}" version | grep -q 'bh-chrome-clone'

echo "== help =="
"${BH}" help | grep -q 'bh-clone'

echo "== unknown command fails =="
if "${BH}" not-a-command 2>/dev/null; then
  echo "expected failure" >&2
  exit 1
fi

echo "SMOKE_CLI_OK"
