#!/usr/bin/env bash
# One-shot: ensure clone + harness env + optional cookie probe note.
# Prepares both browser-harness and chrome-devtools clients.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

SYNC=0
for arg in "$@"; do
  case "${arg}" in
    --sync) SYNC=1 ;;
    -h|--help)
      echo "Usage: bh-clone up [--sync]"
      echo "  Start clone CDP, write harness env, print MCP tip."
      echo "  --sync  also run cookie sync from main Chrome first"
      exit 0
      ;;
  esac
done

if [[ "${SYNC}" == "1" ]]; then
  info "up: syncing cookies first"
  bash "${BH_CLONE_ROOT}/scripts/sync.sh"
fi

bash "${BH_CLONE_ROOT}/scripts/ensure.sh"
write_env_clone
export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"

info "ready for both clients:"
echo
echo "  # browser-harness"
echo "  export BU_CDP_URL=http://127.0.0.1:${BH_CDP_PORT}"
echo "  # or: source ${BH_ENV_FILE}"
echo "  browser-harness <<'PY'"
echo "  print(page_info())"
echo "  PY"
echo
echo "  # chrome-devtools MCP"
echo "  # config: bh-clone mcp print"
echo "  # apply:  bh-clone mcp install-grok   # then restart Grok/MCP"
echo "  # MCP browserUrl must be http://127.0.0.1:${BH_CDP_PORT}"
echo
if cdp_ready "${BH_CDP_PORT}"; then
  info "CDP live: http://127.0.0.1:${BH_CDP_PORT}"
else
  die "CDP not live after ensure"
fi
