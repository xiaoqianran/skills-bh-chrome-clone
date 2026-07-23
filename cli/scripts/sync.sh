#!/usr/bin/env bash
# Export cookies from MAIN Chrome via CDP, inject into automation clone.
# Optional: --with-profile also rsyncs profile files (stops clone first).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

DO_PROFILE_COPY=0
for arg in "$@"; do
  case "${arg}" in
    --with-profile) DO_PROFILE_COPY=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: bh-clone sync [--with-profile]

  Default: export cookies from main Chrome → inject into clone (:9333).
  --with-profile: also rsync main profile into clone (stops clone first).

Env:
  BH_MAIN_PROFILE  BH_CLONE_PROFILE  BH_CDP_PORT  BH_COOKIE_FILE
USAGE
      exit 0
      ;;
    *)
      die "unknown arg: ${arg}"
      ;;
  esac
done

require_browser_harness
require_cmd rsync
require_cmd python3
ensure_state_dir

info "[1/4] export cookies from MAIN Chrome"
info "  (may prompt 'Allow remote debugging?' once — click Allow)"
unset BU_CDP_URL BU_CDP_WS || true
browser-harness --reload >/dev/null 2>&1 || true

# Export via browser-harness; cookie path passed as env for the python snippet
export BH_COOKIE_FILE
browser-harness <<'PY'
import json, os
from pathlib import Path

cookie_path = Path(os.environ.get("BH_COOKIE_FILE", str(Path.home() / ".config/browser-harness/main-cookies.json")))
cookie_path.parent.mkdir(parents=True, exist_ok=True)

cookies = cdp("Network.getAllCookies")["cookies"]
out = []
for c in cookies:
    item = {
        "name": c["name"],
        "value": c["value"],
        "domain": c.get("domain", ""),
        "path": c.get("path", "/"),
        "secure": bool(c.get("secure", False)),
        "httpOnly": bool(c.get("httpOnly", False)),
        "expires": c.get("expires", -1),
    }
    ss = c.get("sameSite")
    if ss:
        item["sameSite"] = ss
    out.append(item)

cookie_path.write_text(json.dumps(out, ensure_ascii=False), encoding="utf-8")
cookie_path.chmod(0o600)

bili = [c for c in out if "bilibili" in c["domain"]]
auth = sorted({c["name"] for c in bili if c["name"] in ("SESSDATA", "DedeUserID", "bili_jct")})
print(f"  exported cookies={len(out)} bilibili={len(bili)} auth={auth}")
print(f"  wrote {cookie_path}")
PY

if [[ "${DO_PROFILE_COPY}" == "1" ]]; then
  info "[2/4] rsync main profile → clone (stopping clone if needed)"
  if cdp_ready "${BH_CDP_PORT}"; then
    kill_clone_chrome
    sleep 1
  fi
  mkdir -p "${BH_CLONE_PROFILE}"
  rsync -a \
    --exclude='SingletonLock' \
    --exclude='SingletonSocket' \
    --exclude='SingletonCookie' \
    --exclude='RunningChromeVersion' \
    --exclude='lockfile' \
    --exclude='*.lock' \
    --exclude='Cache/' \
    --exclude='Code Cache/' \
    --exclude='GPUCache/' \
    --exclude='ShaderCache/' \
    --exclude='GrShaderCache/' \
    --exclude='GraphiteDawnCache/' \
    --exclude='Service Worker/CacheStorage/' \
    --exclude='Service Worker/ScriptCache/' \
    --exclude='Media Cache/' \
    --exclude='Crash Reports/' \
    --exclude='BrowserMetrics/' \
    --exclude='optimization_guide_model_store/' \
    --exclude='component_crx_cache/' \
    --exclude='extensions_crx_cache/' \
    "${BH_MAIN_PROFILE}/" "${BH_CLONE_PROFILE}/"
  strip_clone_locks "${BH_CLONE_PROFILE}"
  enable_remote_debugging_pref "${BH_CLONE_PROFILE}"
  info "  profile copy done: ${BH_CLONE_PROFILE}"
else
  info "[2/4] skip full profile rsync (cookie inject only)"
  if [[ ! -d "${BH_CLONE_PROFILE}" ]]; then
    info "  clone profile missing — performing first-time profile rsync"
    mkdir -p "${BH_CLONE_PROFILE}"
    rsync -a \
      --exclude='SingletonLock' --exclude='SingletonSocket' --exclude='SingletonCookie' \
      --exclude='RunningChromeVersion' --exclude='lockfile' --exclude='*.lock' \
      --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' \
      --exclude='ShaderCache/' --exclude='GrShaderCache/' --exclude='GraphiteDawnCache/' \
      --exclude='Service Worker/CacheStorage/' --exclude='Service Worker/ScriptCache/' \
      --exclude='Media Cache/' --exclude='Crash Reports/' --exclude='BrowserMetrics/' \
      "${BH_MAIN_PROFILE}/" "${BH_CLONE_PROFILE}/"
    strip_clone_locks "${BH_CLONE_PROFILE}"
    enable_remote_debugging_pref "${BH_CLONE_PROFILE}"
  fi
fi

info "[3/4] ensure clone Chrome on :${BH_CDP_PORT}"
bash "${BH_CLONE_ROOT}/scripts/ensure.sh"
if ! cdp_ready "${BH_CDP_PORT}"; then
  die "clone CDP not ready after ensure"
fi

info "[4/4] inject cookies into clone"
export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
export BH_COOKIE_FILE
browser-harness --reload >/dev/null 2>&1 || true
browser-harness <<'PY'
import json, os
from pathlib import Path

cookie_path = Path(os.environ["BH_COOKIE_FILE"])
cookies = json.loads(cookie_path.read_text(encoding="utf-8"))
cdp("Storage.setCookies", cookies=cookies)
allc = cdp("Network.getAllCookies")["cookies"]
auth = [
    c for c in allc
    if c.get("name") in ("SESSDATA", "DedeUserID", "bili_jct")
    and "bilibili" in c.get("domain", "")
]
print(f"  injected; bilibili auth cookies live={len(auth)}")
for c in auth:
    print(f"    {c['name']}@{c['domain']} len={len(c.get('value', ''))}")
print("SYNC_OK")
PY

write_env_clone
info "done. default mode → clone (${BH_CDP_URL})"
info "verify: bh-clone doctor"
