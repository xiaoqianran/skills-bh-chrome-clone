#!/usr/bin/env bash
# Cookie-only sync (default):
#   MAIN  --CDP getAllCookies (read-only)-->  JSON (0600)
#   CLONE --CDP setCookies (write only)---->  inject
#
# HARD_RULES: never kill/restart/rewrite MAIN. Export fail => stop + tell user.
# Optional: --with-profile also rsyncs main → clone (still never stops MAIN).
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

  Cookie-only model (default):
    MAIN  = read-only cookie source (your daily Chrome) — never killed/rewritten
    CLONE = writable automation browser on :9333
    Flow  = getAllCookies(MAIN) → filter → setCookies(CLONE)

  Google-family domains are EXCLUDED by default (google / youtube / gmail / …).

  --with-profile     also rsync main profile → clone (optional; still never stops MAIN)
  --include-google   do NOT exclude Google-family cookies (discouraged)

If MAIN cookie export fails:
  We STOP. Allow remote debugging in your main Chrome yourself, then re-run.
  We will never kill/restart main Chrome to "fix" export.

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

assert_main_clone_distinct
require_browser_harness
require_cmd python3
ensure_state_dir

FILTER_PY="${BH_CLONE_ROOT}/lib/cookie_filter.py"
export BH_COOKIE_FILE
export BH_CLONE_ROOT
export PYTHONPATH="${BH_CLONE_ROOT}/lib${PYTHONPATH:+:${PYTHONPATH}}"

# ── [1/4] READ-ONLY export from MAIN ─────────────────────────────────────────
info "[1/4] READ cookies from MAIN (cookie-only; Google-family excluded by default)"
info "  MAIN is read-only. If Allow popup appears — you click Allow. We never kill MAIN."
unset BU_CDP_URL BU_CDP_WS || true
browser-harness --reload >/dev/null 2>&1 || true

FILTER_SRC="$(cat "${FILTER_PY}")"
export BH_FILTER_SRC="${FILTER_SRC}"

set +e
EXPORT_OUT="$(
browser-harness <<'PY' 2>&1
import json, os, sys
from pathlib import Path
from types import ModuleType

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
google_dropped = sum(
    1 for c in dropped
    if any(x in c.get("domain", "").lower() for x in ("google", "youtube", "gmail"))
)
print(f"  raw={len(out_raw)} kept={len(kept)} dropped={len(dropped)} (google-family-ish≈{google_dropped})")
print(f"  dropped hosts: {mod.summarize_dropped(dropped)}")
print(f"  bilibili={len(bili)} auth={auth}")
print(f"  wrote {cookie_path}")
if any(mod.domain_blocked(c.get("domain", "")) for c in kept):
    raise SystemExit("safety check failed: blocked domain still in kept set")
print("EXPORT_OK")
PY
)"
EXPORT_RC=$?
set -e

printf '%s\n' "${EXPORT_OUT}"
if [[ "${EXPORT_RC}" -ne 0 ]] || ! printf '%s\n' "${EXPORT_OUT}" | grep -q 'EXPORT_OK'; then
  # Never attempt kill/restart MAIN or rewrite main profile as a fallback.
  die_main_cookie_export_failed "$(printf '%s\n' "${EXPORT_OUT}" | tail -n 8 | tr '\n' ' ')"
fi

# ── [2/4] clone profile seed ─────────────────────────────────────────────────
if [[ "${DO_PROFILE_COPY}" == "1" ]]; then
  info "[2/4] optional rsync MAIN → clone (read main, write clone only; MAIN stays up)"
  if cdp_ready "${BH_CDP_PORT}"; then
    kill_clone_chrome || true
    sleep 1
  fi
  rsync_main_to_clone
  info "  profile copy done: ${BH_CLONE_PROFILE}"
else
  info "[2/4] cookie-only: skip full profile rsync"
  if [[ ! -d "${BH_CLONE_PROFILE}" ]]; then
    info "  clone profile missing — create empty dir (no main rsync)"
    ensure_empty_clone_profile
  fi
fi

# ── [3/4] start CLONE only ───────────────────────────────────────────────────
info "[3/4] ensure CLONE Chrome on :${BH_CDP_PORT} (never starts/stops MAIN)"
bash "${BH_CLONE_ROOT}/scripts/ensure.sh"
if ! cdp_ready "${BH_CDP_PORT}"; then
  die "clone CDP not ready after ensure (MAIN was not touched)"
fi

# ── [4/4] WRITE only to CLONE ────────────────────────────────────────────────
info "[4/4] inject filtered cookies into CLONE only + purge Google-family on clone"
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
kept, dropped = mod.filter_cookies(cookies)
if dropped:
    print(f"  re-filter dropped {len(dropped)} before inject")

cdp("Storage.setCookies", cookies=kept)

live = cdp("Network.getAllCookies")["cookies"]
purged = 0
for c in live:
    if not mod.domain_blocked(c.get("domain", "")):
        continue
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
print(f"  injected kept={len(kept)}; purged_google_family={purged}")
print(f"  live total={len(allc)} still_blocked_google_family={len(still_blocked)}")
if still_blocked:
    hosts = sorted({c.get("domain", "") for c in still_blocked})[:15]
    print(f"  WARN remaining blocked hosts: {hosts}")
print("SYNC_OK")
PY

write_env_clone
info "done. cookie-only sync OK. MAIN untouched. mode → clone"
info "verify: bh-clone doctor"
