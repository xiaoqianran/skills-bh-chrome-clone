#!/usr/bin/env bash
# Diagnose clone / cookies / harness / chrome-devtools prerequisites.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_cmd curl
require_cmd python3

ok=0
fail=0
check() {
  local name="$1" status="$2" detail="${3:-}"
  if [[ "${status}" == "ok" ]]; then
    printf '  [ok  ] %s%s\n' "${name}" "${detail:+ — ${detail}}"
    ok=$((ok + 1))
  else
    printf '  [FAIL] %s%s\n' "${name}" "${detail:+ — ${detail}}"
    fail=$((fail + 1))
  fi
}

echo "=== bh-chrome-clone doctor ==="
echo "version intent: dual client (browser-harness + chrome-devtools)"
echo "HARD_RULES: never kill/restart MAIN Chrome — see docs/HARD_RULES.md"
echo "BH_CLONE_ROOT     = ${BH_CLONE_ROOT}"
echo "BH_MAIN_PROFILE   = ${BH_MAIN_PROFILE}"
echo "BH_CLONE_PROFILE  = ${BH_CLONE_PROFILE}"
echo "BH_CDP_PORT       = ${BH_CDP_PORT}"
echo "BH_COOKIE_FILE    = ${BH_COOKIE_FILE}"
echo "BH_ENV_FILE       = ${BH_ENV_FILE}"
echo

echo "=== paths ==="
if [[ -d "${BH_MAIN_PROFILE}" ]]; then check "main profile dir" ok; else check "main profile dir" fail "missing"; fi
if [[ -d "${BH_CLONE_PROFILE}" ]]; then check "clone profile dir" ok; else check "clone profile dir" fail "run: bh-clone init"; fi
if [[ -f "${BH_COOKIE_FILE}" ]]; then check "cookie dump file" ok "mode $(stat -c %a "${BH_COOKIE_FILE}" 2>/dev/null || echo '?')"; else check "cookie dump file" fail "run: bh-clone sync"; fi

echo
echo "=== CDP clone :${BH_CDP_PORT} (shared by harness + chrome-devtools) ==="
if cdp_ready "${BH_CDP_PORT}"; then
  check "clone CDP" ok "http://127.0.0.1:${BH_CDP_PORT}"
  curl -sS --max-time 2 "http://127.0.0.1:${BH_CDP_PORT}/json/version" | python3 -m json.tool 2>/dev/null | sed 's/^/        /' || true
else
  check "clone CDP" fail "run: bh-clone ensure  (or bh-clone up)"
fi

echo
echo "=== cookie snapshot ==="
if [[ -f "${BH_COOKIE_FILE}" ]]; then
  python3 - "${BH_COOKIE_FILE}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
cookies = json.loads(p.read_text())
bili = [c for c in cookies if "bilibili" in c.get("domain", "")]
auth = sorted({c["name"] for c in bili if c["name"] in ("SESSDATA", "DedeUserID", "bili_jct")})
print(f"  total={len(cookies)} bilibili={len(bili)} auth={auth}")
PY
else
  echo "  (no cookie file)"
fi

echo
echo "=== browser-harness client ==="
# bilibili probe is OPTIONAL: not an install gate (HARD_RULES / user may not use bilibili).
# Use BH_DOCTOR_BILI=1 to require isLogin=true as a hard fail.
if command -v browser-harness >/dev/null 2>&1; then
  check "browser-harness binary" ok "$(browser-harness --version 2>/dev/null || echo installed)"
  if cdp_ready "${BH_CDP_PORT}"; then
    export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
    browser-harness --reload >/dev/null 2>&1 || true
    if browser-harness <<'PY' >/tmp/bh-clone-doctor-harness.txt 2>&1
import time, json
new_tab("https://api.bilibili.com/x/web-interface/nav")
wait_for_load()
time.sleep(1)
text = js("document.body.innerText")
print(text[:240])
d = json.loads(text)
raise SystemExit(0 if d.get("data", {}).get("isLogin") is True else 2)
PY
    then
      check "harness CDP smoke (bilibili nav)" ok "isLogin=true"
      sed 's/^/        /' /tmp/bh-clone-doctor-harness.txt | head -5
    else
      if [[ "${BH_DOCTOR_BILI:-0}" == "1" ]]; then
        check "harness bilibili login (required)" fail "run: bh-clone sync (user must Allow on main — do NOT kill main Chrome)"
      else
        # informational only — do not count as hard fail
        printf '  [info ] harness bilibili login — not logged in (optional; not an install failure)\n'
        printf '         set BH_DOCTOR_BILI=1 to require bilibili isLogin\n'
        sed 's/^/        /' /tmp/bh-clone-doctor-harness.txt 2>/dev/null | head -4 || true
      fi
    fi
  else
    check "harness CDP smoke" fail "clone CDP down — run: bh-clone ensure (never kill MAIN Chrome)"
  fi
else
  check "browser-harness binary" fail "uv tool install --python 3.12 browser-harness"
fi

echo
echo "=== chrome-devtools MCP client ==="
echo "  expected: --browserUrl http://127.0.0.1:${BH_CDP_PORT}"
echo "  not:      --auto-connect  (main browser)"
GROK_CFG="${HOME}/.grok/config.toml"
if [[ -f "${GROK_CFG}" ]]; then
  if rg -q 'mcp_servers\.chrome-devtools' "${GROK_CFG}" 2>/dev/null; then
    if rg -q "127.0.0.1:${BH_CDP_PORT}|localhost:${BH_CDP_PORT}" "${GROK_CFG}" \
      && ! rg -q -- '--auto-connect' "${GROK_CFG}"; then
      check "grok chrome-devtools config" ok "points at clone port ${BH_CDP_PORT}"
    elif rg -q -- '--auto-connect' "${GROK_CFG}"; then
      check "grok chrome-devtools config" fail "still --auto-connect; run: bh-clone mcp install-grok"
    else
      check "grok chrome-devtools config" fail "missing browserUrl :${BH_CDP_PORT}; run: bh-clone mcp install-grok"
    fi
  else
    check "grok chrome-devtools config" fail "no chrome-devtools block; run: bh-clone mcp install-grok"
  fi
else
  check "grok config.toml" fail "missing ~/.grok/config.toml (optional if not using Grok)"
fi
echo "  print config:  bh-clone mcp print"
echo "  install grok:  bh-clone mcp install-grok  # then restart MCP host"

echo
echo "=== summary ==="
echo "  ok=${ok} fail=${fail}"
if [[ "${fail}" -gt 0 ]]; then
  echo "  next: bh-clone up [--sync] && bh-clone mcp install-grok"
  exit 1
fi
echo "  both clients can share http://127.0.0.1:${BH_CDP_PORT}"
exit 0
