#!/usr/bin/env bash
# Cookie-only sync (default):
#   MAIN  --CDP getAllCookies (read-only)-->  JSON (0600)
#   CLONE --CDP setCookies (write only)---->  inject
#
# HARD_RULES: never kill/restart/rewrite MAIN. Export fail => stop + tell user.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

DO_PROFILE_COPY=0
INCLUDE_GOOGLE=0
INJECT_ONLY=0

parse_instance_flags "$@"
set -- "${INSTANCE_PARSE_REMAINING[@]+"${INSTANCE_PARSE_REMAINING[@]}"}"

for arg in "$@"; do
  case "${arg}" in
    --with-profile) DO_PROFILE_COPY=1 ;;
    --inject-only) INJECT_ONLY=1 ;;
    --include-google)
      INCLUDE_GOOGLE=1
      warn "INCLUDING Google-family cookies (account risk). Prefer default exclude."
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: bh-clone sync [options]

  Cookie-only: MAIN getAllCookies → filter → CLONE setCookies

Options:
  --instance NAME    target clone worker (default: default)
  --port N           CDP port for that instance
  --with-profile     also rsync main → this clone (never stops MAIN)
  --inject-only      skip MAIN export; inject existing cookie dump into this clone
  --include-google   do NOT exclude Google-family cookies (discouraged)

Multi-open: bh-clone pool start 2 && bh-clone pool sync
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

apply_instance_config
assert_main_clone_distinct
require_browser_harness
require_cmd python3
ensure_state_dir

export BH_COOKIE_FILE
export PYTHONPATH="${BH_CLONE_ROOT}/lib${PYTHONPATH:+:${PYTHONPATH}}"

if [[ "${INJECT_ONLY}" != "1" ]]; then
  # ── [1/4] READ-ONLY export from MAIN ─────────────────────────────────────
  info "[1/4] READ cookies from MAIN (cookie-only; Google-family excluded by default)"
  info "  MAIN is read-only. If Allow popup appears — you click Allow. We never kill MAIN."
  # Must not leave clone BU_CDP_URL set — would export from wrong browser
  unset BU_CDP_URL BU_CDP_WS BU_NAME || true
  browser-harness --reload >/dev/null 2>&1 || true

  set +e
  EXPORT_OUT="$(
  browser-harness <<'PY' 2>&1
from cookie_io import normalize_cdp_cookies, write_cookie_dump, export_summary

raw = cdp("Network.getAllCookies")["cookies"]
items = normalize_cdp_cookies(raw)
kept, dropped, path = write_cookie_dump(items, filter_google=True)
s = export_summary(kept, dropped)
print(
    f"  raw={len(items)} kept={s['kept']} dropped={s['dropped']} "
    f"(google-family-ish≈{s['google_family_ish_dropped']})"
)
print(f"  dropped hosts: {s['dropped_hosts']}")
print(f"  zhihu={s['zhihu']} has_z_c0={s['has_z_c0']}")
print(f"  bilibili={s['bilibili']} auth={s['bilibili_auth']}")
print(f"  wrote {path}")
print("EXPORT_OK")
PY
  )"
  EXPORT_RC=$?
  set -e

  printf '%s\n' "${EXPORT_OUT}"
  if [[ "${EXPORT_RC}" -ne 0 ]] || ! printf '%s\n' "${EXPORT_OUT}" | grep -q 'EXPORT_OK'; then
    die_main_cookie_export_failed "$(printf '%s\n' "${EXPORT_OUT}" | tail -n 8 | tr '\n' ' ')"
  fi
else
  info "[1/4] inject-only: skip MAIN export (use existing ${BH_COOKIE_FILE})"
  [[ -f "${BH_COOKIE_FILE}" ]] || die "cookie dump missing: ${BH_COOKIE_FILE} (run bh-clone sync once without --inject-only)"
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
info "[3/4] ensure CLONE [${BH_INSTANCE}] on :${BH_CDP_PORT} (never starts/stops MAIN)"
bash "${BH_CLONE_ROOT}/scripts/ensure.sh" --instance "${BH_INSTANCE}" --port "${BH_CDP_PORT}"
apply_instance_config
if ! cdp_ready "${BH_CDP_PORT}"; then
  die "clone CDP not ready after ensure (MAIN was not touched)"
fi

# ── [4/4] WRITE only to CLONE ────────────────────────────────────────────────
info "[4/4] inject cookies into CLONE [${BH_INSTANCE}] ${BH_CDP_URL} (BU_NAME=${BH_BU_NAME})"
export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
export BU_NAME="${BH_BU_NAME}"
export BH_COOKIE_FILE
browser-harness --reload >/dev/null 2>&1 || true
browser-harness <<'PY'
from cookie_filter import domain_blocked
from cookie_io import cookies_for_inject

kept, dropped = cookies_for_inject()
if dropped:
    print(f"  re-filter dropped {len(dropped)} before inject")

cdp("Storage.setCookies", cookies=kept)

live = cdp("Network.getAllCookies")["cookies"]
purged = 0
for c in live:
    if not domain_blocked(c.get("domain", "")):
        continue
    domain = c.get("domain") or ""
    path = c.get("path") or "/"
    try:
        cdp("Network.deleteCookies", name=c["name"], domain=domain, path=path)
        purged += 1
    except Exception as e:
        print(f"  purge warn {c.get('name')}@{domain}: {e}")

allc = cdp("Network.getAllCookies")["cookies"]
still_blocked = [c for c in allc if domain_blocked(c.get("domain", ""))]
print(f"  injected kept={len(kept)}; purged_google_family={purged}")
print(f"  live total={len(allc)} still_blocked_google_family={len(still_blocked)}")
if still_blocked:
    hosts = sorted({c.get("domain", "") for c in still_blocked})[:15]
    print(f"  WARN remaining blocked hosts: {hosts}")
print("SYNC_OK")
PY

write_env_clone
info "done. cookie-only sync OK. instance=${BH_INSTANCE} port=${BH_CDP_PORT} MAIN untouched"
info "verify: source ${BH_ENV_FILE} && browser-harness --doctor"
