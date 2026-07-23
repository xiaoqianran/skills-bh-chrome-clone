#!/usr/bin/env bash
# Diagnose clone / main / cookie / CDP health.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_cmd curl
require_cmd python3

echo "=== bh-chrome-clone doctor ==="
echo "BH_CLONE_ROOT     = ${BH_CLONE_ROOT}"
echo "BH_MAIN_PROFILE   = ${BH_MAIN_PROFILE}  exists=$([[ -d ${BH_MAIN_PROFILE} ]] && echo yes || echo NO)"
echo "BH_CLONE_PROFILE  = ${BH_CLONE_PROFILE}  exists=$([[ -d ${BH_CLONE_PROFILE} ]] && echo yes || echo NO)"
echo "BH_CDP_PORT       = ${BH_CDP_PORT}"
echo "BH_COOKIE_FILE    = ${BH_COOKIE_FILE}  exists=$([[ -f ${BH_COOKIE_FILE} ]] && echo yes || echo NO)"
echo "BH_ENV_FILE       = ${BH_ENV_FILE}"
if [[ -f "${BH_ENV_FILE}" ]]; then
  echo "--- env file ---"
  sed 's/^/  /' "${BH_ENV_FILE}"
fi

echo
echo "=== CDP :${BH_CDP_PORT} ==="
if cdp_ready "${BH_CDP_PORT}"; then
  echo "  [ok] clone CDP responding"
  curl -sS --max-time 2 "http://127.0.0.1:${BH_CDP_PORT}/json/version" | python3 -m json.tool 2>/dev/null | sed 's/^/  /' || true
else
  echo "  [FAIL] clone CDP not up — run: bh-clone ensure"
fi

echo
echo "=== cookie snapshot (names only) ==="
if [[ -f "${BH_COOKIE_FILE}" ]]; then
  python3 - "${BH_COOKIE_FILE}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
cookies = json.loads(p.read_text())
bili = [c for c in cookies if "bilibili" in c.get("domain", "")]
auth = sorted({c["name"] for c in bili if c["name"] in ("SESSDATA", "DedeUserID", "bili_jct")})
print(f"  total={len(cookies)} bilibili={len(bili)} auth_present={auth}")
print(f"  file_mode={oct(p.stat().st_mode & 0o777)}")
PY
else
  echo "  [FAIL] no cookie file — run: bh-clone sync"
fi

echo
echo "=== browser-harness ==="
if command -v browser-harness >/dev/null 2>&1; then
  # Prefer clone if CDP up
  if cdp_ready "${BH_CDP_PORT}"; then
    export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
  else
    unset BU_CDP_URL BU_CDP_WS || true
  fi
  browser-harness --doctor 2>&1 | sed 's/^/  /'
else
  echo "  [FAIL] browser-harness not installed"
  echo "  install: uv tool install --python 3.12 --upgrade browser-harness"
fi

echo
echo "=== bilibili login probe (clone only) ==="
if cdp_ready "${BH_CDP_PORT}" && command -v browser-harness >/dev/null 2>&1; then
  export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
  browser-harness --reload >/dev/null 2>&1 || true
  if browser-harness <<'PY'
import time
new_tab("https://api.bilibili.com/x/web-interface/nav")
wait_for_load()
time.sleep(1)
text = js("document.body.innerText")
print(text[:280])
ok = '"isLogin":true' in text.replace(" ", "") or '"isLogin": true' in text
raise SystemExit(0 if ok else 2)
PY
  then
    echo "  [ok] bilibili isLogin=true on clone"
  else
    echo "  [FAIL] bilibili not logged in on clone — run: bh-clone sync"
  fi
else
  echo "  [skip] clone CDP or browser-harness unavailable"
fi
