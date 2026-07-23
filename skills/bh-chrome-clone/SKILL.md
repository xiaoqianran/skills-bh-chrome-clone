---
name: bh-chrome-clone
description: "Cookie-only Chrome session twin: READ cookies from main Chrome, WRITE into dedicated clone on CDP :9333 for browser-harness and chrome-devtools MCP. NEVER kill/restart/rewrite the user's daily main Chrome. Use when: authenticated automation, bh-clone, or chrome-devtools without auto-connect."
---

# bh-chrome-clone

**Cookie-only session twin** shared by:

| Client | How it connects |
|--------|-----------------|
| **browser-harness** | `export BU_CDP_URL=http://127.0.0.1:9333` |
| **chrome-devtools MCP** | `--browserUrl http://127.0.0.1:9333` (**not** `--auto-connect`) |

```text
MAIN ──read getAllCookies──► JSON ──write setCookies──► CLONE :9333
```

CLI: `bh-clone` (install from this repo).

## Upstream browser-harness (required on new machines)

This skill does **not** ship browser-harness. Install official:

- **Repo:** https://github.com/browser-use/browser-harness  
- **Install:** https://github.com/browser-use/browser-harness/blob/main/install.md  
- **This repo:** [`docs/BROWSER_HARNESS.md`](../../docs/BROWSER_HARNESS.md) · `./scripts/setup-browser-harness.sh`  

Then: `bh-clone up` + `export BU_CDP_URL=http://127.0.0.1:9333`.  
Register the official skill: `browser-harness skill > ~/.grok/skills/browser-harness/SKILL.md` (and codex/claude). Restart the agent host.

## ⛔ HARD RULES + cookie-only — 违反即事故

- [`docs/HARD_RULES.md`](../../docs/HARD_RULES.md) — 禁止事项（冲突时以它为准）  
- [`docs/COOKIE_ONLY.md`](../../docs/COOKIE_ONLY.md) — 默认只复制 cookie  
- [`docs/BROWSER_HARNESS.md`](../../docs/BROWSER_HARNESS.md) — 上游 harness 官方地址  



### 绝对禁止（主浏览器）

1. **禁止** kill / 重启 **主** Chrome  
2. **禁止** 删/改主 profile Singleton* / Local State / Cookies / Storage  
3. **禁止** 主 profile + `--remote-debugging-port`  
4. **禁止** 在主浏览器上 deleteCookies / 写回  
5. **禁止** 导出失败后用「杀主浏览器」fallback  
6. **禁止** 打印 cookie；默认不要 `--include-google`  
7. **禁止** 未要求就测 bilibili/grok 登录  

### 允许

- `bh-clone sync|init|ensure|up|doctor|mcp …`  
- MAIN 只读导出；CLONE 注入；kill **仅** clone  
- 导出失败：CLI 会打印标准说明 → **请用户** Allow → 再 sync  

### 导出失败

```text
停 → 用户 chrome://inspect/#remote-debugging Allow → bh-clone sync
禁止：kill 主 Chrome / 删 Singleton / 改 Local State
```

---

## When to use

| Situation | Action |
|-----------|--------|
| Need logged-in automation | `bh-clone up` then harness / chrome-devtools |
| Site login missing **and user needs that site** | `bh-clone sync` (Allow **once** on main if prompted) |
| First machine setup | `./install.sh` → `bh-clone init`（cookie-only）→ `mcp install-grok`（**不动**主进程） |
| chrome-devtools still on main | `bh-clone mcp install-grok` + restart MCP host |
| Public static page | Prefer curl/fetch — no browser |

`doctor` 里 bilibili 未登录 **≠** 安装失败（除非用户要做 B 站自动化）。

## Prerequisites

```bash
# Upstream (required): https://github.com/browser-use/browser-harness
# Full steps: https://github.com/browser-use/browser-harness/blob/main/install.md
./scripts/setup-browser-harness.sh   # or follow install.md manually
./install.sh                         # this repo CLI + skills (+ harness if not skipped)
```

Chrome/Chromium required. Main profile default: `~/.config/google-chrome` — **read/export only via bh-clone sync, never kill.**

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
Forbidden: `--auto-connect` to daily Chrome.

### C. Health

```bash
bh-clone doctor
```

Checks: clone CDP, cookie file, optional harness probe, Grok MCP pointing at clone.  
Treat optional site-login probes as informational unless the user asked for that site.

## Critical rules (summary)

1. **Never print or commit** `~/.config/browser-harness/main-cookies.json`.
2. Prefer **clone** for automation; **main** only for live human tabs (`bh-clone use main` 只改 env，不杀进程).
3. Do not spam main CDP if Allow popup appears — ask user to click Allow once.
4. Start clone **before** chrome-devtools MCP connects (`bh-clone ensure` / `up`).
5. Skill + CLI only — not a new MCP server.
6. **Never sync Google-family cookies by default.** No `--include-google` unless user explicitly accepts risk.
7. **Never kill, reconfigure, or wipe the user's main Chrome.** See `docs/HARD_RULES.md`.
8. **Default is cookie-only** (`docs/COOKIE_ONLY.md`); `--with-profile` is optional.

## Command map

```text
bh-clone init [--with-profile]
bh-clone sync [--with-profile] | ensure | up [--sync]
bh-clone use clone|main
bh-clone mcp print|json|install-grok|check
bh-clone doctor
```

## See also

- `docs/HARD_RULES.md` ← **必读**
- `docs/COOKIE_ONLY.md` ← **默认模型**
- `docs/BROWSER_HARNESS.md` ← **上游官方 GitHub + 新环境配置**
- https://github.com/browser-use/browser-harness
- https://github.com/browser-use/browser-harness/blob/main/install.md
- `references/chrome-devtools-mcp.md`
- `references/architecture.md`
- `docs/design.md`
- `AGENTS.md`
