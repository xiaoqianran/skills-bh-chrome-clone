#!/usr/bin/env bash
# First-time setup: profile rsync + cookie sync + ensure + write env.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_browser_harness
info "init: full profile copy + cookie sync"
bash "${BH_CLONE_ROOT}/scripts/sync.sh" --with-profile
info "init complete"
info "next: bh-clone doctor"
