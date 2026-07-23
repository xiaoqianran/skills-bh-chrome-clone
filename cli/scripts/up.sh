#!/usr/bin/env bash
# One-shot: ensure clone + harness env + optional cookie sync.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

SYNC=0
parse_instance_flags "$@"
set -- "${INSTANCE_PARSE_REMAINING[@]+"${INSTANCE_PARSE_REMAINING[@]}"}"
for arg in "$@"; do
  case "${arg}" in
    --sync) SYNC=1 ;;
    -h|--help)
      echo "Usage: bh-clone up [--sync] [--instance NAME] [--port N]"
      echo "  Start one clone CDP, write harness env (BU_CDP_URL + BU_NAME)."
      echo "  Multi-open: bh-clone pool start 2"
      exit 0
      ;;
  esac
done

apply_instance_config
assert_main_clone_distinct

if [[ "${SYNC}" == "1" ]]; then
  info "up: cookie-only sync first (MAIN read-only; never kill MAIN)"
  bash "${BH_CLONE_ROOT}/scripts/sync.sh" --instance "${BH_INSTANCE}" --port "${BH_CDP_PORT}"
fi

bash "${BH_CLONE_ROOT}/scripts/ensure.sh" --instance "${BH_INSTANCE}" --port "${BH_CDP_PORT}"
apply_instance_config
write_env_clone
export BU_CDP_URL="http://127.0.0.1:${BH_CDP_PORT}"
export BU_NAME="${BH_BU_NAME}"

info "ready clone [${BH_INSTANCE}] for harness + chrome-devtools:"
echo
echo "  source ${BH_ENV_FILE}"
echo "  # BU_CDP_URL=${BH_CDP_URL}  BU_NAME=${BH_BU_NAME}"
echo "  browser-harness <<'PY'"
echo "  print(page_info())"
echo "  PY"
echo
echo "  # Multi-open (parallel workers):  bh-clone pool start 2 && bh-clone pool env"
echo
if cdp_ready "${BH_CDP_PORT}"; then
  info "CLONE [${BH_INSTANCE}] live: ${BH_CDP_URL}"
else
  die "CLONE CDP not live after ensure (MAIN was not touched)"
fi
