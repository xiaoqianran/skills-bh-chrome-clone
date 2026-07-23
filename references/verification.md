# Verification log

## 2026-07-23 — v0.2.0 dual-client

| Step | Result |
|------|--------|
| `cli/tests/smoke_cli.sh` | SMOKE_CLI_OK |
| `bh-clone version` | 0.2.0 |
| `bh-clone up` | CDP :9333 live |
| `bh-clone mcp install-grok` | config browserUrl :9333 |
| `bh-clone doctor` | ok=7 fail=0 |
| browser-harness bilibili nav | isLogin=true, mid 3707026140039918 |
| chrome-devtools config check | points at clone, no auto-connect |

Note: chrome-devtools **runtime** requires MCP host restart after config change; doctor validates config file + shared CDP, not in-process MCP.

## Earlier 0.1.x

- Search `清华学生如何学习` on clone returned real video titles
- Cookie inject required (rsync alone dropped SESSDATA)
