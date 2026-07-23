---
name: bh-chrome-clone
description: "Chrome session twin for browser-harness and chrome-devtools MCP: copy login cookies into a dedicated CDP browser (:9333), avoid main-browser Allow popups. Use when: authenticated automation, bilibili/session sites, bh-clone, or configuring chrome-devtools without auto-connect."
---

# bh-chrome-clone

One **automation Chrome** (session twin) shared by:

| Client | How it connects |
|--------|-----------------|
| **browser-harness** | `export BU_CDP_URL=http://127.0.0.1:9333` |
| **chrome-devtools MCP** | `--browserUrl http://127.0.0.1:9333` (**not** `--auto-connect`) |

Cookies come from the user's **main** Chrome via CDP export → inject (profile rsync alone is not enough).

CLI: `bh-clone` (install from this repo).

## When to use

| Situation | Action |
|-----------|--------|
| Need logged-in automation | `bh-clone up` then harness / chrome-devtools |
| `isLogin:false` / 未登录 | `bh-clone sync` (Allow **once** on main if prompted) |
| First machine setup | `bh-clone init` then `bh-clone mcp install-grok` |
| chrome-devtools still on main | `bh-clone mcp install-grok` + restart MCP host |
| Public static page | Prefer curl/fetch — no browser |

## Prerequisites

```bash
uv tool install --python 3.12 --upgrade browser-harness
./install.sh   # from repo root
```

Chrome/Chromium required. Main profile default: `~/.config/google-chrome`.

## Agent workflow

### A. browser-harness

```bash
bh-clone ensure   # or: bh-clone up
export BU_CDP_URL=http://127.0.0.1:9333
# optional: source ~/.config/browser-harness/env

browser-harness <<'PY'
ensure_real_tab()
print(page_info())
PY
```

### B. chrome-devtools MCP

1. `bh-clone ensure`
2. MCP config must use clone URL only:

```bash
bh-clone mcp print
bh-clone mcp install-grok   # Grok ~/.grok/config.toml
# restart Grok / IDE so MCP reloads
```

Expected args: `--browserUrl http://127.0.0.1:9333`  
Forbidden for this skill: `--auto-connect` to daily Chrome.

### C. Health

```bash
bh-clone doctor
```

Checks: clone CDP, cookie file, harness bilibili login, Grok MCP pointing at clone.

### D. Site adapters (optional)

```bash
opencli bilibili subtitle BVxxxx -f json
opencli bilibili summary BVxxxx -f json
```

## Critical rules

1. **Never print or commit** `~/.config/browser-harness/main-cookies.json`.
2. Prefer **clone** for automation; **main** only for live human tabs (`bh-clone use main`).
3. Do not spam main CDP if Allow popup appears — ask user to click Allow once.
4. Start clone **before** chrome-devtools MCP connects (`bh-clone ensure` / `up`).
5. Skill + CLI only — not a new MCP server. Existing MCP is chrome-devtools attached to the twin.

## Command map

```text
bh-clone init | sync [--with-profile] | ensure | up [--sync]
bh-clone use clone|main
bh-clone mcp print|json|install-grok|check
bh-clone doctor
```

## See also

- `references/chrome-devtools-mcp.md`
- `references/architecture.md`
- `docs/design.md`
- `AGENTS.md`
