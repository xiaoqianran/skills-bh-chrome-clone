#!/usr/bin/env bash
# Offline smoke: CLI wiring + hard-rule messages (no live browser required).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BH="${ROOT}/bin/bh-clone"
REPO="$(cd "${ROOT}/.." && pwd)"

echo "== version =="
ver="$("${BH}" version)"
echo "${ver}" | grep -qE 'bh-chrome-clone 0\.2\.7'
# version single source
grep -q 'BH_CLONE_VERSION:=0.2.7' "${ROOT}/lib/common.sh"

echo "== help cookie-only / hard rules =="
help_out="$("${BH}" help)"
echo "${help_out}" | grep -q 'cookie-only'
echo "${help_out}" | grep -q 'never kill'
echo "${help_out}" | grep -q 'chrome-devtools'
echo "${help_out}" | grep -q 'browser-harness'

echo "== mcp print =="
out="$("${BH}" mcp print)"
echo "${out}" | grep -q 'browserUrl'
echo "${out}" | grep -q '127.0.0.1:9333'
if echo "${out}" | grep -v '^#' | grep -q -- '--auto-connect'; then
  echo "mcp print args must not use --auto-connect" >&2
  exit 1
fi

echo "== mcp json =="
"${BH}" mcp json | grep -q 'chrome-devtools'

echo "== sync help cookie-only =="
sync_help="$("${BH}" sync --help)"
echo "${sync_help}" | grep -qi 'cookie-only'
echo "${sync_help}" | grep -qE 'inject-only|instance|pool'

echo "== docs present =="
test -f "${REPO}/docs/HARD_RULES.md"
test -f "${REPO}/docs/COOKIE_ONLY.md"
test -f "${REPO}/docs/BROWSER_HARNESS.md"
grep -q 'getAllCookies' "${REPO}/docs/COOKIE_ONLY.md"
grep -qE 'kill|主 Chrome|HARD RULES' "${REPO}/docs/HARD_RULES.md"
grep -q 'github.com/browser-use/browser-harness' "${REPO}/docs/BROWSER_HARNESS.md"
test -f "${ROOT}/lib/cookie_io.py"

echo "== use main refused without opt-in =="
if BH_ALLOW_USE_MAIN=0 "${BH}" use main 2>/tmp/bh-use-main.err; then
  echo "expected use main to refuse without BH_ALLOW_USE_MAIN=1" >&2
  exit 1
fi
grep -qiE 'BH_ALLOW_USE_MAIN|refused' /tmp/bh-use-main.err

echo "== no fuser invoke in kill_clone =="
if awk '/^kill_clone_chrome\(/,/^}/' "${ROOT}/lib/common.sh" | grep -vE '^\s*#' | grep -qE '\bfuser\b'; then
  echo "kill_clone_chrome must not invoke fuser" >&2
  exit 1
fi

echo "== cookie_io importable =="
PYTHONPATH="${ROOT}/lib" python3 -c 'from cookie_io import write_cookie_dump, export_summary; print("io_ok")'

echo "== pool help / multi-instance flags =="
"${BH}" pool 2>&1 | grep -q 'pool start'
"${BH}" help | grep -q 'pool start'
grep -q 'apply_instance_config' "${ROOT}/lib/common.sh"
grep -q 'BU_NAME' "${ROOT}/lib/common.sh"

echo "== unknown command fails =="
if "${BH}" not-a-command 2>/dev/null; then
  echo "expected failure" >&2
  exit 1
fi

echo "SMOKE_CLI_OK"
