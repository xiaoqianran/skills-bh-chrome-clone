#!/usr/bin/env bash
# Install CLI + register Agent skill (Grok / Codex / Claude skill dirs).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SKILL_SRC="${ROOT}/skills/bh-chrome-clone"

mkdir -p "${BIN_DIR}"

chmod +x "${ROOT}/cli/bin/bh-clone" "${ROOT}/cli/install.sh" \
  "${ROOT}/cli/scripts/"*.sh "${ROOT}/cli/tests/"*.sh 2>/dev/null || true

ln -sfn "${ROOT}/cli/bin/bh-clone" "${BIN_DIR}/bh-clone"
bash "${ROOT}/cli/install.sh" >/dev/null 2>&1 || true

link_skill() {
  local dest_parent="$1"
  mkdir -p "${dest_parent}"
  ln -sfn "${SKILL_SRC}" "${dest_parent}/bh-chrome-clone"
  echo "skill linked: ${dest_parent}/bh-chrome-clone"
}

mkdir -p "${HOME}/.grok/skills" 2>/dev/null || true
link_skill "${HOME}/.grok/skills"
mkdir -p "${HOME}/.codex/skills" 2>/dev/null || true
link_skill "${HOME}/.codex/skills"
if [[ -d "${HOME}/.claude" ]] || mkdir -p "${HOME}/.claude/skills" 2>/dev/null; then
  link_skill "${HOME}/.claude/skills"
fi

echo
echo "installed: ${BIN_DIR}/bh-clone -> ${ROOT}/cli/bin/bh-clone"
echo "version:   $(${BIN_DIR}/bh-clone version 2>/dev/null || echo '?')"
echo
echo "next:"
echo "  1) uv tool install --python 3.12 --upgrade browser-harness"
echo "  2) bh-clone init          # first time"
echo "  3) bh-clone up"
echo "  4) bh-clone mcp install-grok   # chrome-devtools on clone; restart MCP host"
echo "  5) bh-clone doctor"
if ! command -v browser-harness >/dev/null 2>&1; then
  echo
  echo "note: browser-harness not found yet (step 1)."
fi
