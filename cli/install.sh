#!/usr/bin/env bash
# Install bh-clone onto PATH (~/.local/bin)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"

chmod +x "${ROOT}/bin/bh-clone"
chmod +x "${ROOT}/scripts/"*.sh
chmod +x "${ROOT}/lib/common.sh" 2>/dev/null || true

ln -sfn "${ROOT}/bin/bh-clone" "${BIN_DIR}/bh-clone"

# Optional legacy aliases pointing at the new CLI
ln -sfn "${ROOT}/bin/bh-clone" "${BIN_DIR}/browser-harness-clone" 2>/dev/null || true

echo "installed: ${BIN_DIR}/bh-clone -> ${ROOT}/bin/bh-clone"
echo "try: bh-clone help"
if ! command -v browser-harness >/dev/null 2>&1; then
  echo "note: browser-harness not found. Install with:"
  echo "  uv tool install --python 3.12 --upgrade browser-harness"
fi
