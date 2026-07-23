#!/usr/bin/env bash
# Switch browser-harness to live main Chrome (may need Allow once).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_browser_harness
unset BU_CDP_URL BU_CDP_WS || true
write_env_main
browser-harness --reload >/dev/null 2>&1 || true
info "mode: MAIN Chrome (live; may prompt Allow remote debugging)"
browser-harness --doctor 2>&1 | sed -n '1,30p'
