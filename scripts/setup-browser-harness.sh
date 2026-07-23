#!/usr/bin/env bash
# Install & register official browser-harness for a new machine.
# Upstream (source of truth):
#   https://github.com/browser-use/browser-harness
#   https://github.com/browser-use/browser-harness/blob/main/install.md
#
# Does NOT kill the user's main Chrome. Optional: start clone via bh-clone if present.
set -euo pipefail

UPSTREAM_REPO="https://github.com/browser-use/browser-harness"
UPSTREAM_INSTALL="https://github.com/browser-use/browser-harness/blob/main/install.md"

export PATH="${HOME}/.local/bin:${PATH}"

echo "[setup-browser-harness] upstream: ${UPSTREAM_REPO}"
echo "[setup-browser-harness] install:  ${UPSTREAM_INSTALL}"
echo

if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv not found. Install: https://github.com/astral-sh/uv" >&2
  exit 1
fi

echo "[1/4] uv tool install --python 3.12 --upgrade --force browser-harness"
uv tool install --python 3.12 --upgrade --force browser-harness
browser-harness --version

echo
echo "[2/4] register browser-harness skill (official body from CLI)"
SKILL_BODY="$(browser-harness skill)"
register_skill() {
  local dest="$1"
  mkdir -p "${dest}"
  printf '%s\n' "${SKILL_BODY}" > "${dest}/SKILL.md"
  echo "  -> ${dest}/SKILL.md"
}
register_skill "${CODEX_HOME:-$HOME/.codex}/skills/browser-harness"
register_skill "${HOME}/.claude/skills/browser-harness"
register_skill "${HOME}/.grok/skills/browser-harness"
if [[ -d "${HOME}/.cursor" ]] || mkdir -p "${HOME}/.cursor/skills" 2>/dev/null; then
  register_skill "${HOME}/.cursor/skills/browser-harness"
fi

echo
echo "[3/4] recordings default: off (install.md consent default N)"
if browser-harness recordings 2>&1 | grep -qiE '\(config\)|\(BH_RECORD\)'; then
  echo "  keep existing recording preference"
  browser-harness recordings 2>&1 || true
else
  browser-harness recordings disable
  browser-harness recordings 2>&1 || true
fi

echo
echo "[4/4] point harness at clone if bh-clone is available"
if command -v bh-clone >/dev/null 2>&1; then
  bh-clone ensure || true
  mkdir -p "${HOME}/.config/browser-harness"
  cat > "${HOME}/.config/browser-harness/env" <<'EOF'
# Official browser-harness + this repo's clone (see docs/BROWSER_HARNESS.md)
# Upstream: https://github.com/browser-use/browser-harness
export PATH="${HOME}/.local/bin:${PATH}"
export BU_CDP_URL=http://127.0.0.1:9333
export BH_CDP_PORT=9333
export BH_CLONE_PROFILE="${HOME}/.config/browser-harness-chrome-clone"
export BH_COOKIE_FILE="${HOME}/.config/browser-harness/main-cookies.json"
EOF
  echo "  wrote ~/.config/browser-harness/env (BU_CDP_URL=:9333)"
  echo "  smoke: source ~/.config/browser-harness/env && browser-harness <<'PY'"
  echo "         print(page_info())"
  echo "         PY"
else
  echo "  bh-clone not in PATH — install this repo (./install.sh), then:"
  echo "    bh-clone up && export BU_CDP_URL=http://127.0.0.1:9333"
  echo "  Or attach MAIN Chrome per official install.md (user must Allow remote debugging)."
fi

echo
echo "done."
echo "  version: $(browser-harness --version 2>/dev/null || echo '?')"
echo "  docs:    docs/BROWSER_HARNESS.md"
echo "  upstream install.md: ${UPSTREAM_INSTALL}"
echo "  restart Agent hosts so the browser-harness skill is loaded."
