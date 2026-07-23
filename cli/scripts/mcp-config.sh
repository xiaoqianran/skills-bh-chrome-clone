#!/usr/bin/env bash
# Print or install chrome-devtools MCP config for the clone CDP.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

usage() {
  cat <<USAGE
Usage: bh-clone mcp <print|snippet|install-grok|check>

  print         Full TOML snippet for [mcp_servers.chrome-devtools]
  snippet       Same as print
  install-grok  Write/update ~/.grok/config.toml to use clone browserUrl
  check         Verify clone CDP is up (MCP prerequisite)

Port: ${BH_CDP_PORT}  URL: http://127.0.0.1:${BH_CDP_PORT}
USAGE
}

print_toml() {
  cat <<EOF
# bh-chrome-clone — chrome-devtools on session twin (no --auto-connect)
# Run first: bh-clone ensure && bh-clone sync
# Then restart Grok / MCP host so this server reloads.

[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@latest",
    "--browserUrl",
    "http://127.0.0.1:${BH_CDP_PORT}",
]
enabled = true
startup_timeout_sec = 90
EOF
}

print_json() {
  cat <<EOF
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl",
        "http://127.0.0.1:${BH_CDP_PORT}"
      ]
    }
  }
}
EOF
}

install_grok() {
  local cfg="${HOME}/.grok/config.toml"
  mkdir -p "${HOME}/.grok"
  if [[ ! -f "${cfg}" ]]; then
    info "creating ${cfg}"
    cat > "${cfg}" <<EOF
[cli]
installer = "internal"

EOF
  fi

  python3 - "${cfg}" "${BH_CDP_PORT}" <<'PY'
import re, sys
from pathlib import Path

path = Path(sys.argv[1])
port = sys.argv[2]
text = path.read_text(encoding="utf-8")

block = f'''# bh-chrome-clone: chrome-devtools → session twin (no main auto-connect)
# Prerequisite: bh-clone ensure  (login: bh-clone sync)
[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@latest",
    "--browserUrl",
    "http://127.0.0.1:{port}",
]
enabled = true
startup_timeout_sec = 90
'''

# Replace existing chrome-devtools server table if present (including leading comments)
pat = re.compile(
    r"(?ms)^(?:#[^\n]*\n)*\[mcp_servers\.chrome-devtools\]\n.*?(?=^\[|\Z)"
)
if pat.search(text):
    text = pat.sub(block.rstrip() + "\n\n", text, count=1)
    action = "updated"
else:
    if not text.endswith("\n"):
        text += "\n"
    text += "\n" + block
    action = "appended"

path.write_text(text, encoding="utf-8")
print(f"  {action} {path}")
print(f"  browserUrl=http://127.0.0.1:{port}")
print("  restart Grok/MCP host to apply")
PY
  info "install-grok done"
}

cmd="${1:-print}"
case "${cmd}" in
  print|snippet)
    print_toml
    ;;
  json)
    print_json
    ;;
  install-grok)
    install_grok
    ;;
  check)
    if cdp_ready "${BH_CDP_PORT}"; then
      info "clone CDP OK http://127.0.0.1:${BH_CDP_PORT}"
      curl -sS --max-time 2 "http://127.0.0.1:${BH_CDP_PORT}/json/version" | head -c 300
      echo
    else
      die "clone CDP down — run: bh-clone ensure"
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    die "unknown mcp subcommand: ${cmd}"
    ;;
esac
