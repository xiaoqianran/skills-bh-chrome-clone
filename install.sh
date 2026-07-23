#!/usr/bin/env bash
# Install CLI + register Agent skill (Grok / Codex / Claude skill dirs).
#
# browser-harness is UPSTREAM — not vendored here. Official:
#   https://github.com/browser-use/browser-harness
#   https://github.com/browser-use/browser-harness/blob/main/install.md
# Full new-env harness setup: ./scripts/setup-browser-harness.sh
# Docs: docs/BROWSER_HARNESS.md
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SKILL_SRC="${ROOT}/skills/bh-chrome-clone"
export PATH="${BIN_DIR}:${PATH}"

mkdir -p "${BIN_DIR}"

chmod +x "${ROOT}/cli/bin/bh-clone" "${ROOT}/cli/install.sh" \
  "${ROOT}/cli/scripts/"*.sh "${ROOT}/cli/tests/"*.sh \
  "${ROOT}/scripts/"*.sh 2>/dev/null || true

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

# Optional: also set up official browser-harness (skip with BH_SKIP_HARNESS=1)
if [[ "${BH_SKIP_HARNESS:-0}" != "1" ]]; then
  if command -v uv >/dev/null 2>&1; then
    echo
    echo "setting up upstream browser-harness (official install.md)..."
    bash "${ROOT}/scripts/setup-browser-harness.sh" || {
      echo "WARN: setup-browser-harness.sh failed — install manually:"
      echo "  https://github.com/browser-use/browser-harness/blob/main/install.md"
    }
  else
    echo
    echo "note: uv not found — skip auto harness install."
    echo "  official: https://github.com/browser-use/browser-harness"
    echo "  install:  https://github.com/browser-use/browser-harness/blob/main/install.md"
    echo "  or later: ./scripts/setup-browser-harness.sh"
  fi
fi

echo
echo "installed: ${BIN_DIR}/bh-clone -> ${ROOT}/cli/bin/bh-clone"
echo "version:   $(${BIN_DIR}/bh-clone version 2>/dev/null || echo '?')"
echo
echo "upstream browser-harness:"
echo "  repo:    https://github.com/browser-use/browser-harness"
echo "  install: https://github.com/browser-use/browser-harness/blob/main/install.md"
echo "  local:   docs/BROWSER_HARNESS.md  |  ./scripts/setup-browser-harness.sh"
echo
echo "next:"
echo "  1) bh-clone init          # cookie-only; never kills MAIN"
echo "  2) bh-clone up"
echo "  3) source ~/.config/browser-harness/env   # BU_CDP_URL=:9333"
echo "  4) bh-clone mcp install-grok   # chrome-devtools on clone; restart MCP host"
echo "  5) bh-clone doctor"
echo "  6) restart Agent host so skills load (bh-chrome-clone + browser-harness)"
if ! command -v browser-harness >/dev/null 2>&1; then
  echo
  echo "note: browser-harness still missing — run:"
  echo "  ./scripts/setup-browser-harness.sh"
  echo "  # or: https://github.com/browser-use/browser-harness/blob/main/install.md"
fi
