# Changelog

## 0.2.2

### Docs / Safety (HARD RULES)

- Add **[docs/HARD_RULES.md](docs/HARD_RULES.md)**: absolute bans on killing/reconfiguring the user's **main** Chrome
- Wire rules into `AGENTS.md`, Skill, README, design, architecture
- Clarify: doctor bilibili probe is optional, not an install gate
- `kill_clone_chrome` guards: refuse main-like profiles; only default clone path unless override

### Why

Agents must never "fix" CDP/sync by restarting daily Chrome — that can wipe logins (e.g. grok.com) permanently.

## 0.2.1

### Security

- Cookie sync **excludes Google-family domains by default** (google / youtube / gmail / …)
- After inject, purge Google-family cookies already present on the clone
- `BH_EXCLUDE_DOMAINS` for extra suffixes; `--include-google` opt-in only (discouraged)

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
