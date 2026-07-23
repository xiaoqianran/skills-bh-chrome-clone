#!/usr/bin/env bash
# Install CLI + register Agent skill (Grok / Codex-style skill dirs).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SKILL_SRC="${ROOT}/skills/bh-chrome-clone"

mkdir -p "${BIN_DIR}"

# CLI
chmod +x "${ROOT}/cli/bin/bh-clone" "${ROOT}/cli/install.sh" "${ROOT}/cli/scripts/"*.sh "${ROOT}/cli/tests/"*.sh
# Point bh-clone install into PATH
ln -sfn "${ROOT}/cli/bin/bh-clone" "${BIN_DIR}/bh-clone"
# Also run nested install for consistency messages
bash "${ROOT}/cli/install.sh" >/dev/null

# Skills: Grok + Codex if present
link_skill() {
  local dest_parent="$1"
  mkdir -p "${dest_parent}"
  ln -sfn "${SKILL_SRC}" "${dest_parent}/bh-chrome-clone"
  echo "skill linked: ${dest_parent}/bh-chrome-clone"
}

if [[ -d "${HOME}/.grok/skills" ]] || mkdir -p "${HOME}/.grok/skills" 2>/dev/null; then
  link_skill "${HOME}/.grok/skills"
fi
if [[ -d "${HOME}/.codex/skills" ]] || mkdir -p "${HOME}/.codex/skills" 2>/dev/null; then
  link_skill "${HOME}/.codex/skills"
fi
# Claude Code plugin-style path (optional)
if [[ -d "${HOME}/.claude" ]]; then
  mkdir -p "${HOME}/.claude/skills"
  link_skill "${HOME}/.claude/skills"
fi

echo
echo "installed CLI: ${BIN_DIR}/bh-clone -> ${ROOT}/cli/bin/bh-clone"
echo "try: bh-clone help && bh-clone doctor"
if ! command -v browser-harness >/dev/null 2>&1; then
  echo "note: install browser-harness:"
  echo "  uv tool install --python 3.12 --upgrade browser-harness"
fi
