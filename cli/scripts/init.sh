#!/usr/bin/env bash
# First-time setup — cookie-only by default (never kills MAIN).
#   init                 → sync (empty clone + cookie inject)
#   init --with-profile  → also rsync main → clone (optional)
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

assert_main_clone_distinct
require_browser_harness

WITH_PROFILE=()
for arg in "$@"; do
  case "${arg}" in
    --with-profile) WITH_PROFILE=(--with-profile) ;;
    -h|--help)
      cat <<'USAGE'
Usage: bh-clone init [--with-profile]

  Cookie-only first setup (default):
    - create empty clone profile if needed
    - READ cookies from MAIN (you may need to Allow remote debugging)
    - WRITE cookies into CLONE on :9333
    - never kill/restart MAIN

  --with-profile  also rsync main profile → clone (optional)

If cookie export fails, init stops and prints what you should do in MAIN.
We never "fix" export by restarting your daily browser.
USAGE
      exit 0
      ;;
    *)
      die "unknown arg: ${arg}"
      ;;
  esac
done

info "init: cookie-only model (MAIN read-only → CLONE write)"
info "  HARD_RULES: MAIN process/profile will not be killed or rewritten"
bash "${BH_CLONE_ROOT}/scripts/sync.sh" "${WITH_PROFILE[@]+"${WITH_PROFILE[@]}"}"
info "init complete"
info "next: bh-clone up && bh-clone mcp install-grok   # optional MCP"
info "      bh-clone doctor"
