#!/usr/bin/env bash
# Shared helpers for bh-chrome-clone
#
# Model (see docs/HARD_RULES.md + docs/COOKIE_ONLY.md):
#   MAIN  = read-only cookie source (user's daily Chrome) — never kill/rewrite
#   CLONE = only writable automation browser (:9333)
#   Flow  = MAIN --getAllCookies--> JSON --setCookies--> CLONE
# shellcheck disable=SC2034

set -euo pipefail

BH_CLONE_ROOT="${BH_CLONE_ROOT:-}"
if [[ -z "${BH_CLONE_ROOT}" ]]; then
  _COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  BH_CLONE_ROOT="$(cd "${_COMMON_DIR}/.." && pwd)"
fi
BH_REPO_ROOT="$(cd "${BH_CLONE_ROOT}/.." && pwd)"

# Single source of truth for CLI version (bh-clone sources this)
: "${BH_CLONE_VERSION:=0.2.6}"

: "${BH_MAIN_PROFILE:=${HOME}/.config/google-chrome}"
: "${BH_CLONE_PROFILE:=${HOME}/.config/browser-harness-chrome-clone}"
: "${BH_CDP_PORT:=9333}"
: "${BH_COOKIE_FILE:=${HOME}/.config/browser-harness/main-cookies.json}"
: "${BH_STATE_DIR:=${HOME}/.config/browser-harness}"
: "${BH_CLONE_LOG:=/tmp/browser-harness-chrome-clone.log}"
: "${BH_ENV_FILE:=${HOME}/.config/browser-harness/env}"
: "${BH_CDP_URL:=http://127.0.0.1:${BH_CDP_PORT}}"
: "${PATH:=${PATH}}"
: "${BH_EXCLUDE_DOMAINS:=}"
: "${BH_INCLUDE_GOOGLE:=0}"

export PATH="${HOME}/.local/bin:${PATH}"

log()  { printf '%s\n' "$*"; }
info() { printf '[bh-clone] %s\n' "$*"; }
warn() { printf '[bh-clone] WARN: %s\n' "$*" >&2; }
die()  { printf '[bh-clone] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

load_user_env() {
  if [[ -f "${BH_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${BH_ENV_FILE}" || true
  fi
}

ensure_state_dir() {
  mkdir -p "${BH_STATE_DIR}"
  chmod 700 "${BH_STATE_DIR}" 2>/dev/null || true
}

# --- path / hard-rule guards -------------------------------------------------

_norm_path() {
  local p="$1"
  if [[ -d "${p}" ]]; then
    (cd "${p}" && pwd -P)
  elif [[ -e "${p}" ]]; then
    local d b
    d="$(cd "$(dirname "${p}")" && pwd -P)"
    b="$(basename "${p}")"
    printf '%s/%s\n' "${d}" "${b}"
  else
    printf '%s\n' "${p}"
  fi
}

# True if profile is empty or is the user's MAIN daily Chrome profile.
# Empty → true (refuse dangerous ops on empty path).
is_main_profile_path() {
  local profile="$1"
  [[ -z "${profile}" ]] && return 0

  local main="${BH_MAIN_PROFILE}"
  local candidates=(
    "${main}"
    "${HOME}/.config/google-chrome"
    "${HOME}/.config/chromium"
    "${HOME}/.config/google-chrome-stable"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -z "${c}" ]] && continue
    [[ "${profile}" == "${c}" ]] && return 0
  done

  if [[ -d "${profile}" && -d "${main}" ]]; then
    [[ "$(_norm_path "${profile}")" == "$(_norm_path "${main}")" ]] && return 0
  fi
  return 1
}

assert_main_clone_distinct() {
  if is_main_profile_path "${BH_CLONE_PROFILE}"; then
    die "BH_CLONE_PROFILE must not be the main Chrome profile (HARD_RULES): ${BH_CLONE_PROFILE}"
  fi
  if [[ -d "${BH_CLONE_PROFILE}" && -d "${BH_MAIN_PROFILE}" ]]; then
    if [[ "$(_norm_path "${BH_CLONE_PROFILE}")" == "$(_norm_path "${BH_MAIN_PROFILE}")" ]]; then
      die "clone profile path resolves to main profile (HARD_RULES)"
    fi
  fi
}

assert_not_main_profile() {
  local profile="$1"
  local what="${2:-operation}"
  if is_main_profile_path "${profile}"; then
    die "refused ${what} on MAIN profile: ${profile} (see docs/HARD_RULES.md)"
  fi
}

# Clone kill/start paths must look like the harness twin (or explicit override).
is_default_clone_profile() {
  local profile="${1:-${BH_CLONE_PROFILE}}"
  [[ "${profile}" == *browser-harness-chrome-clone* ]]
}

die_main_cookie_export_failed() {
  local detail="${1:-}"
  cat >&2 <<EOF
[bh-clone] ERROR: could not READ cookies from MAIN Chrome (export failed).
${detail:+[bh-clone] detail: ${detail}
}
[bh-clone] ── cookie-only model ──────────────────────────────────────────
  MAIN  = read-only source (your daily browser) — we never kill/rewrite it
  CLONE = only writable target (:${BH_CDP_PORT})
  Flow  = MAIN --getAllCookies--> JSON --setCookies--> CLONE

[bh-clone] What YOU can do (we will not touch main Chrome for you):
  1) Keep your normal Chrome running with the logins you need
  2) Open chrome://inspect/#remote-debugging
  3) Allow remote debugging for this browser instance (click Allow if prompted)
  4) Re-run: bh-clone sync

[bh-clone] What we will NEVER do:
  - kill / restart your main Chrome
  - delete Singleton* or rewrite Local State / Cookies on main profile
  - launch main profile with --remote-debugging-port

[bh-clone] Full rules: ${BH_REPO_ROOT}/docs/HARD_RULES.md
[bh-clone] Cookie-only: ${BH_REPO_ROOT}/docs/COOKIE_ONLY.md
EOF
  exit 1
}

cdp_ready() {
  local port="${1:-${BH_CDP_PORT}}"
  curl -sS --max-time 1 "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

wait_cdp() {
  local port="${1:-${BH_CDP_PORT}}"
  local tries="${2:-40}"
  local i
  for i in $(seq 1 "${tries}"); do
    if cdp_ready "${port}"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

require_browser_harness() {
  require_cmd browser-harness
  require_cmd curl
  if ! command -v google-chrome >/dev/null 2>&1 \
    && ! command -v google-chrome-stable >/dev/null 2>&1 \
    && ! command -v chromium >/dev/null 2>&1; then
    die "google-chrome or chromium not found in PATH"
  fi
}

chrome_bin() {
  if command -v google-chrome >/dev/null 2>&1; then
    command -v google-chrome
  elif command -v google-chrome-stable >/dev/null 2>&1; then
    command -v google-chrome-stable
  elif command -v chromium >/dev/null 2>&1; then
    command -v chromium
  else
    die "Chrome/Chromium binary not found"
  fi
}

write_env_clone() {
  ensure_state_dir
  cat > "${BH_ENV_FILE}" <<EOF
# Generated by bh-chrome-clone — automation clone mode (cookie-only target)
export PATH="\${HOME}/.local/bin:\${PATH}"
export BU_CDP_URL=http://127.0.0.1:${BH_CDP_PORT}
export BH_CDP_PORT=${BH_CDP_PORT}
export BH_CLONE_PROFILE="${BH_CLONE_PROFILE}"
export BH_COOKIE_FILE="${BH_COOKIE_FILE}"
EOF
}

write_env_main() {
  ensure_state_dir
  cat > "${BH_ENV_FILE}" <<'EOF'
# Generated by bh-chrome-clone — main Chrome mode (env only; does not kill processes)
export PATH="${HOME}/.local/bin:${PATH}"
unset BU_CDP_URL
unset BU_CDP_WS
EOF
}

strip_clone_locks() {
  local profile="${1:-${BH_CLONE_PROFILE}}"
  assert_not_main_profile "${profile}" "strip_clone_locks"
  find "${profile}" -maxdepth 2 \( \
    -name 'Singleton*' -o -name 'lockfile' -o -name 'RunningChromeVersion' \
  \) -delete 2>/dev/null || true
}

enable_remote_debugging_pref() {
  local profile="${1:-${BH_CLONE_PROFILE}}"
  assert_not_main_profile "${profile}" "enable_remote_debugging_pref"
  local state="${profile}/Local State"
  [[ -f "${state}" ]] || return 0
  python3 - "${state}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8", errors="replace"))
data.setdefault("devtools", {}).setdefault("remote_debugging", {})["user-enabled"] = True
p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
PY
}

ensure_empty_clone_profile() {
  assert_main_clone_distinct
  assert_not_main_profile "${BH_CLONE_PROFILE}" "ensure_empty_clone_profile"
  mkdir -p "${BH_CLONE_PROFILE}"
  strip_clone_locks "${BH_CLONE_PROFILE}"
}

rsync_main_to_clone() {
  assert_main_clone_distinct
  assert_not_main_profile "${BH_CLONE_PROFILE}" "rsync_main_to_clone"
  require_cmd rsync
  if [[ ! -d "${BH_MAIN_PROFILE}" ]]; then
    die "main profile missing (read-only source): ${BH_MAIN_PROFILE}"
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
  enable_remote_debugging_pref "${BH_CLONE_PROFILE}" || true
}

# List PIDs that are safe to kill for the clone profile (stdout: one pid per line).
# Empty if none. Never includes MAIN. Does not kill.
list_clone_pids() {
  local profile="${1:-${BH_CLONE_PROFILE}}"
  assert_not_main_profile "${profile}" "list_clone_pids"
  if [[ ${#profile} -lt 12 ]]; then
    die "refuse list_clone_pids: profile path too short (HARD_RULES): ${profile}"
  fi
  if ! is_default_clone_profile "${profile}" && [[ "${BH_ALLOW_CUSTOM_CLONE_KILL:-0}" != "1" ]]; then
    return 0
  fi

  local pids pid cmdline
  pids="$(pgrep -f "user-data-dir=${profile}" 2>/dev/null || true)"
  [[ -z "${pids}" ]] && return 0

  for pid in ${pids}; do
    [[ -r "/proc/${pid}/cmdline" ]] || continue
    cmdline="$(tr '\0' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"
    # Must match this exact user-data-dir value
    [[ "${cmdline}" == *"user-data-dir=${profile}"* ]] || continue
    # Never kill a process that only targets MAIN profile path
    if is_main_profile_path "${profile}"; then
      continue
    fi
    printf '%s\n' "${pid}"
  done
}

kill_clone_chrome() {
  # ONLY the automation twin. See docs/HARD_RULES.md.
  # Kill ONLY by clone user-data-dir. No pkill by name. No fuser by port.
  #
  # NOTE: do not use process substitution < <(list_clone_pids) — a die() inside
  # the subshell would not abort this function (HARD_RULES false negative).
  local profile="${BH_CLONE_PROFILE}"
  assert_main_clone_distinct
  assert_not_main_profile "${profile}" "kill_clone_chrome"

  if ! is_default_clone_profile "${profile}" && [[ "${BH_ALLOW_CUSTOM_CLONE_KILL:-0}" != "1" ]]; then
    warn "clone profile is non-default (${profile}); set BH_ALLOW_CUSTOM_CLONE_KILL=1 to kill"
    return 1
  fi

  local pid_file pid any=0
  pid_file="$(mktemp)"
  # list_clone_pids may die() on short/main paths — runs in this shell, exits correctly
  list_clone_pids "${profile}" >"${pid_file}" || {
    rm -f "${pid_file}"
    return 1
  }

  while IFS= read -r pid; do
    [[ -z "${pid}" ]] && continue
    any=1
    kill "${pid}" 2>/dev/null || true
  done <"${pid_file}"
  rm -f "${pid_file}"

  if [[ "${any}" == "1" ]]; then
    sleep 1
  fi
}
