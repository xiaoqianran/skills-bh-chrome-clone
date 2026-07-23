# Agent notes — skills-bh-chrome-clone

## What this is

Session twin for authenticated browser automation:

- **CLI `bh-clone`**: copies login cookies into a dedicated Chrome on CDP `:9333`
- **Skill `bh-chrome-clone`**: when/how to use it
- **Clients**:
  - **browser-harness** via `BU_CDP_URL=http://127.0.0.1:9333`
  - **chrome-devtools MCP** via `--browserUrl http://127.0.0.1:9333` (never `--auto-connect` main)

## Default agent policy

1. Prefer clone for multi-step / unattended work.
2. Before tools: `bh-clone ensure` (or `bh-clone up`).
3. If login fails: `bh-clone sync` (user may Allow once on **main**).
4. Do not dump cookie file contents into chat.
5. Public pages → curl/fetch; browser only when interaction/login needed.

## Commands

```bash
bh-clone init | sync | ensure | up [--sync]
bh-clone use clone|main
bh-clone mcp print | install-grok | check
bh-clone doctor
```
