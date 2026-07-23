#!/usr/bin/env bash
# Switch browser-harness to automation clone mode.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_browser_harness
bash "${BH_CLONE_ROOT}/scripts/ensure.sh"
write_env_clone
export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
browser-harness --reload >/dev/null 2>&1 || true
info "mode: CLONE @ ${BU_CDP_URL}"
browser-harness --doctor 2>&1 | sed -n '1,30p'
