#!/usr/bin/env bash
# Export cookies from MAIN Chrome via CDP, inject into automation clone.
# Default: NEVER sync Google-family domains (account safety).
# Optional: --with-profile also rsyncs profile files (stops clone first).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

DO_PROFILE_COPY=0
INCLUDE_GOOGLE=0
for arg in "$@"; do
  case "${arg}" in
    --with-profile) DO_PROFILE_COPY=1 ;;
    --include-google)
      INCLUDE_GOOGLE=1
      warn "INCLUDING Google-family cookies (account risk). Prefer default exclude."
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: bh-clone sync [--with-profile] [--include-google]

  Default: export cookies from main Chrome → inject into clone (:9333).
  Google-family domains are EXCLUDED by default (google / youtube / gmail / …).

  --with-profile     also rsync main profile into clone (stops clone first)
  --include-google   do NOT exclude Google-family cookies (discouraged)

Env:
  BH_MAIN_PROFILE  BH_CLONE_PROFILE  BH_CDP_PORT  BH_COOKIE_FILE
  BH_EXCLUDE_DOMAINS   extra comma-separated domain suffixes to skip
  BH_INCLUDE_GOOGLE=1  same as --include-google
USAGE
      exit 0
      ;;
    *)
      die "unknown arg: ${arg}"
      ;;
  esac
done

if [[ "${INCLUDE_GOOGLE}" == "1" ]]; then
  export BH_INCLUDE_GOOGLE=1
fi

require_browser_harness
require_cmd rsync
require_cmd python3
ensure_state_dir

FILTER_PY="${BH_CLONE_ROOT}/lib/cookie_filter.py"
export BH_COOKIE_FILE
export BH_CLONE_ROOT
export PYTHONPATH="${BH_CLONE_ROOT}/lib${PYTHONPATH:+:${PYTHONPATH}}"

info "[1/4] export cookies from MAIN Chrome (Google-family excluded by default)"
info "  (may prompt 'Allow remote debugging?' once — click Allow)"
info "  HARD_RULES: never kill/restart main Chrome if this fails — stop and ask the user"
unset BU_CDP_URL BU_CDP_WS || true
browser-harness --reload >/dev/null 2>&1 || true

# Export via browser-harness; filter runs inside the snippet via embedded logic
# (harness process may not see PYTHONPATH — embed filter source).
FILTER_SRC="$(cat "${FILTER_PY}")"
export BH_FILTER_SRC="${FILTER_SRC}"

browser-harness <<'PY'
import json, os, sys
from pathlib import Path
from types import ModuleType

# Load cookie_filter from source string (reliable inside harness exec)
src = os.environ.get("BH_FILTER_SRC", "")
mod = ModuleType("cookie_filter")
exec(src, mod.__dict__)  # noqa: S102 — our own filter module

cookie_path = Path(os.environ.get("BH_COOKIE_FILE", str(Path.home() / ".config/browser-harness/main-cookies.json")))
cookie_path.parent.mkdir(parents=True, exist_ok=True)

raw = cdp("Network.getAllCookies")["cookies"]
out_raw = []
for c in raw:
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
    out_raw.append(item)

kept, dropped = mod.filter_cookies(out_raw)
cookie_path.write_text(json.dumps(kept, ensure_ascii=False), encoding="utf-8")
cookie_path.chmod(0o600)

bili = [c for c in kept if "bilibili" in c["domain"]]
auth = sorted({c["name"] for c in bili if c["name"] in ("SESSDATA", "DedeUserID", "bili_jct")})
google_dropped = sum(1 for c in dropped if "google" in c.get("domain", "").lower() or "youtube" in c.get("domain", "").lower() or "gmail" in c.get("domain", "").lower())
print(f"  raw={len(out_raw)} kept={len(kept)} dropped={len(dropped)} (google-family-ish≈{google_dropped})")
print(f"  dropped hosts: {mod.summarize_dropped(dropped)}")
print(f"  bilibili={len(bili)} auth={auth}")
print(f"  wrote {cookie_path}")
if any(mod.domain_blocked(c.get("domain", "")) for c in kept):
    raise SystemExit("safety check failed: blocked domain still in kept set")
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

info "[4/4] inject filtered cookies + purge Google-family cookies already on clone"
export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
export BH_COOKIE_FILE
export BH_FILTER_SRC
browser-harness --reload >/dev/null 2>&1 || true
browser-harness <<'PY'
import json, os
from pathlib import Path
from types import ModuleType

src = os.environ.get("BH_FILTER_SRC", "")
mod = ModuleType("cookie_filter")
exec(src, mod.__dict__)  # noqa: S102

cookie_path = Path(os.environ["BH_COOKIE_FILE"])
cookies = json.loads(cookie_path.read_text(encoding="utf-8"))
# defense in depth: filter again before inject
kept, dropped = mod.filter_cookies(cookies)
if dropped:
    print(f"  re-filter dropped {len(dropped)} before inject")

cdp("Storage.setCookies", cookies=kept)

# Purge any Google-family cookies already present on clone (e.g. from old profile rsync)
live = cdp("Network.getAllCookies")["cookies"]
purged = 0
for c in live:
    if not mod.domain_blocked(c.get("domain", "")):
        continue
    params = {
        "name": c["name"],
        "url": None,
    }
    # Network.deleteCookies wants name + url or domain/path
    domain = c.get("domain") or ""
    path = c.get("path") or "/"
    try:
        cdp(
            "Network.deleteCookies",
            name=c["name"],
            domain=domain,
            path=path,
        )
        purged += 1
    except Exception as e:
        print(f"  purge warn {c.get('name')}@{domain}: {e}")

allc = cdp("Network.getAllCookies")["cookies"]
still_blocked = [c for c in allc if mod.domain_blocked(c.get("domain", ""))]
auth = [
    c for c in allc
    if c.get("name") in ("SESSDATA", "DedeUserID", "bili_jct")
    and "bilibili" in c.get("domain", "")
]
print(f"  injected kept={len(kept)}; purged_google_family={purged}")
print(f"  live total={len(allc)} still_blocked_google_family={len(still_blocked)}")
print(f"  bilibili auth cookies live={len(auth)}")
for c in auth:
    print(f"    {c['name']}@{c['domain']} len={len(c.get('value', ''))}")
if still_blocked:
    hosts = sorted({c.get("domain", "") for c in still_blocked})[:15]
    print(f"  WARN remaining blocked hosts: {hosts}")
print("SYNC_OK")
PY

write_env_clone
info "done. Google-family cookies excluded. mode → clone"
info "verify: bh-clone doctor"
