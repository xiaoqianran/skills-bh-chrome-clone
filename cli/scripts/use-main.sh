#!/usr/bin/env bash
# Switch browser-harness env to live MAIN Chrome (env file only — never kills processes).
#
# HARD_RULES: This does NOT kill/restart MAIN. It only unsets BU_CDP_URL so harness
# may attach to MAIN if the user already allowed remote debugging.
# Prefer clone for automation. Require explicit opt-in to avoid accidental MAIN attach.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [[ "${BH_ALLOW_USE_MAIN:-0}" != "1" ]]; then
  cat >&2 <<'EOF'
[bh-clone] ERROR: refused `use main` without BH_ALLOW_USE_MAIN=1

  Automation should use the CLONE (default):
    bh-clone use clone
    # or: source ~/.config/browser-harness/env

  Pointing harness at MAIN risks tab fights / Allow popups on your daily browser.
  It does not kill MAIN, but is opt-in only.

  If you really need it:
    BH_ALLOW_USE_MAIN=1 bh-clone use main
EOF
  exit 1
fi

require_browser_harness
unset BU_CDP_URL BU_CDP_WS || true
write_env_main
browser-harness --reload >/dev/null 2>&1 || true
info "mode: MAIN Chrome env only (no process kill; may prompt Allow)"
info "HARD_RULES: do not kill/restart MAIN if doctor fails — enable remote debugging yourself"
browser-harness --doctor 2>&1 | sed -n '1,30p'
