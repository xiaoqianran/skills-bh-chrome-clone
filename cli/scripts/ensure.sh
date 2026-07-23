#!/usr/bin/env bash
# Ensure automation clone Chrome is running with remote debugging.
# Supports multi-instance: --instance NAME [--port N]
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

parse_instance_flags "$@"
set -- "${INSTANCE_PARSE_REMAINING[@]+"${INSTANCE_PARSE_REMAINING[@]}"}"
for arg in "$@"; do
  case "${arg}" in
    -h|--help)
      echo "Usage: bh-clone ensure [--instance NAME] [--port N]"
      echo "  Start one CLONE (never MAIN). Multi-open: different --instance per worker."
      exit 0
      ;;
  esac
done

apply_instance_config
require_browser_harness
ensure_state_dir
assert_main_clone_distinct
assert_not_main_profile "${BH_CLONE_PROFILE}" "ensure (start clone)"

if is_main_profile_path "${BH_CLONE_PROFILE}"; then
  die "refuse ensure: BH_CLONE_PROFILE is MAIN (HARD_RULES)"
fi

if cdp_ready "${BH_CDP_PORT}"; then
  # Port up is not enough — must be THIS instance's user-data-dir (multi-open safety)
  own_pids="$(list_clone_pids "${BH_CLONE_PROFILE}" | tr '\n' ' ')"
  if [[ -n "${own_pids// /}" ]]; then
    info "clone [${BH_INSTANCE}] CDP already up on :${BH_CDP_PORT} (own profile)"
    write_env_clone
    exit 0
  fi
  # Port held by another process/profile — reallocate (never attach to foreign Chrome)
  warn "port :${BH_CDP_PORT} busy but not instance '${BH_INSTANCE}' profile; allocating free port"
  BH_CDP_PORT_EXPLICIT="$(instance_next_port)"
  BH_CDP_PORT="${BH_CDP_PORT_EXPLICIT}"
  BH_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
  register_instance
fi

if [[ ! -d "${BH_CLONE_PROFILE}" ]]; then
  info "clone profile missing — create empty dir (cookie-only; no main rsync)"
  ensure_empty_clone_profile
fi

CHROME="$(chrome_bin)"
info "starting CLONE [${BH_INSTANCE}]: profile=${BH_CLONE_PROFILE} port=${BH_CDP_PORT} BU_NAME=${BH_BU_NAME}"
info "  (MAIN Chrome is not started, stopped, or rewritten)"
nohup "${CHROME}" \
  --remote-debugging-port="${BH_CDP_PORT}" \
  --user-data-dir="${BH_CLONE_PROFILE}" \
  --no-first-run \
  --no-default-browser-check \
  --disable-sync \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --test-type \
  about:blank >>"${BH_CLONE_LOG}" 2>&1 &

if wait_cdp "${BH_CDP_PORT}" 40; then
  info "clone [${BH_INSTANCE}] CDP ready: ${BH_CDP_URL} (BU_NAME=${BH_BU_NAME})"
  write_env_clone
  exit 0
fi

die "failed to start clone [${BH_INSTANCE}] on :${BH_CDP_PORT} (see ${BH_CLONE_LOG})"
