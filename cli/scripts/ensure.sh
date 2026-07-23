#!/usr/bin/env bash
# Ensure automation clone Chrome is running with remote debugging.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_browser_harness
ensure_state_dir
assert_main_clone_distinct
assert_not_main_profile "${BH_CLONE_PROFILE}" "ensure (start clone)"

# Refuse launching clone onto a path that is MAIN (belt + suspenders)
if is_main_profile_path "${BH_CLONE_PROFILE}"; then
  die "refuse ensure: BH_CLONE_PROFILE is MAIN (HARD_RULES)"
fi

if cdp_ready "${BH_CDP_PORT}"; then
  info "clone CDP already up on :${BH_CDP_PORT}"
  exit 0
fi

if [[ ! -d "${BH_CLONE_PROFILE}" ]]; then
  info "clone profile missing — create empty dir (cookie-only; no main rsync)"
  ensure_empty_clone_profile
fi

CHROME="$(chrome_bin)"
info "starting CLONE only: profile=${BH_CLONE_PROFILE} port=${BH_CDP_PORT}"
info "  (MAIN Chrome is not started, stopped, or rewritten)"
# Always pass --user-data-dir=CLONE. Never omit (would attach default MAIN profile).
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
  info "clone CDP ready: ${BH_CDP_URL}"
  exit 0
fi

die "failed to start clone Chrome on :${BH_CDP_PORT} (see ${BH_CLONE_LOG})"
