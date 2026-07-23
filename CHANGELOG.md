# Changelog

## 0.2.0

### Features

- Dual-client support: **browser-harness** + **chrome-devtools MCP** on the same clone
- `bh-clone up [--sync]` one-shot ready for both clients
- `bh-clone mcp print|json|install-grok|check`
- Doctor checks Grok MCP config (clone browserUrl, no auto-connect)
- MCP config templates under `cli/config/`
- AGENTS.md + expanded README / SKILL

### Docs

- End-to-end install for harness and chrome-devtools
- Architecture diagram and client comparison table

## 0.1.0

- Initial Skill + CLI (init/sync/ensure/use/doctor)
- Cookie CDP inject session twin
