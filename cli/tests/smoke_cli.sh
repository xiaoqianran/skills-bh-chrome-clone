#!/usr/bin/env bash
# Offline smoke: CLI wiring + hard-rule messages (no live browser required).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BH="${ROOT}/bin/bh-clone"
REPO="$(cd "${ROOT}/.." && pwd)"

echo "== version =="
"${BH}" version | grep -qE 'bh-chrome-clone 0\.2\.3'

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
echo "${sync_help}" | grep -q 'Cookie-only'
echo "${sync_help}" | grep -q 'never kill'

echo "== docs present =="
test -f "${REPO}/docs/HARD_RULES.md"
test -f "${REPO}/docs/COOKIE_ONLY.md"
grep -q 'getAllCookies' "${REPO}/docs/COOKIE_ONLY.md"
grep -qE 'kill|主 Chrome|HARD RULES' "${REPO}/docs/HARD_RULES.md"

echo "== refuse kill main profile =="
# die() exits the shell — run guards in a subshell; capture stdout+stderr
set +e
kill_err="$(
  {
    # shellcheck source=../lib/common.sh
    source "${ROOT}/lib/common.sh"
    BH_CLONE_PROFILE="${HOME}/.config/google-chrome"
    kill_clone_chrome
    echo SURVIVED
  } 2>&1
)"
kill_rc=$?
set -e
echo "${kill_err}" | grep -qiE 'refuse|HARD_RULES|MAIN|main' \
  || { echo "expected HARD_RULES refuse message: ${kill_err}" >&2; exit 1; }
[[ "${kill_rc}" -ne 0 ]] || { echo "expected non-zero from kill_clone on main" >&2; exit 1; }
echo "${kill_err}" | grep -q SURVIVED && { echo "kill_clone should not continue on main" >&2; exit 1; }

echo "== refuse enable_remote_debugging on main =="
set +e
pref_err="$(
  {
    # shellcheck source=../lib/common.sh
    source "${ROOT}/lib/common.sh"
    enable_remote_debugging_pref "${HOME}/.config/google-chrome"
    echo SURVIVED
  } 2>&1
)"
pref_rc=$?
set -e
[[ "${pref_rc}" -ne 0 ]] || { echo "expected refuse main pref write: ${pref_err}" >&2; exit 1; }
echo "${pref_err}" | grep -qiE 'refuse|HARD_RULES|MAIN|main' \
  || { echo "expected refuse message: ${pref_err}" >&2; exit 1; }

echo "== unknown command fails =="
if "${BH}" not-a-command 2>/dev/null; then
  echo "expected failure" >&2
  exit 1
fi

echo "SMOKE_CLI_OK"
