---
name: bh-chrome-clone
description: "Chrome session twin for browser-harness and chrome-devtools MCP: copy login cookies into a dedicated CDP browser (:9333), avoid main-browser Allow popups. Use when: authenticated automation, bilibili/session sites, bh-clone, or configuring chrome-devtools without auto-connect. NEVER kill or reconfigure the user's daily main Chrome."
---

# bh-chrome-clone

One **automation Chrome** (session twin) shared by:

| Client | How it connects |
|--------|-----------------|
| **browser-harness** | `export BU_CDP_URL=http://127.0.0.1:9333` |
| **chrome-devtools MCP** | `--browserUrl http://127.0.0.1:9333` (**not** `--auto-connect`) |

Cookies come from the user's **main** Chrome via CDP export → inject (profile rsync alone is not enough).

CLI: `bh-clone` (install from this repo).

## ⛔ HARD RULES — 违反即事故

**权威全文：仓库内 [`docs/HARD_RULES.md`](../../docs/HARD_RULES.md)（冲突时以它为准）。**

### 绝对禁止（主浏览器 = 用户日常 Chrome）

1. **禁止** kill / pkill / killall / 强杀 **主** Chrome / Chromium 进程  
2. **禁止** 为开远程调试、init、sync、doctor 而**重启**主浏览器  
3. **禁止** 删除/改写主 profile 的 `Singleton*`、`Local State`、`Preferences`、Cookies、Storage  
4. **禁止** 用主 profile 加 `--remote-debugging-port` 拉起「调试版日常浏览器」  
5. **禁止** 在主浏览器上 `Network.deleteCookies` / 清站点数据 / 向主 profile 写回  
6. **禁止** 把 cookie 明文打进对话或 git  
7. **禁止** 默认 `--include-google`；**禁止** 未要求就测 bilibili/grok 等站登录  

强杀主 Chrome 可导致 **grok.com 等登录永久丢失**。不要重演。

### 允许

- 只操作 clone：`~/.config/browser-harness-chrome-clone` + `:9333`  
- `bh-clone ensure|up|sync|doctor|mcp …`  
- sync 时 **请用户** 在主 Chrome 点一次 Allow；导出失败就停，**不要**杀主浏览器曲线救国  

### 导出 cookie 失败时

```text
告知用户 → chrome://inspect/#remote-debugging 允许调试
或先 ensure clone，登录态等用户允许后再 sync
禁止：kill 主 Chrome / 删 Singleton / 改 Local State / 主 profile 开 RDP 重启
```

---

## When to use

| Situation | Action |
|-----------|--------|
| Need logged-in automation | `bh-clone up` then harness / chrome-devtools |
| Site login missing **and user needs that site** | `bh-clone sync` (Allow **once** on main if prompted) |
| First machine setup | `./install.sh` → `bh-clone init` → `mcp install-grok`（**不动**主进程） |
| chrome-devtools still on main | `bh-clone mcp install-grok` + restart MCP host |
| Public static page | Prefer curl/fetch — no browser |

`doctor` 里 bilibili 未登录 **≠** 安装失败（除非用户要做 B 站自动化）。

## Prerequisites

```bash
uv tool install --python 3.12 --upgrade browser-harness
./install.sh   # from repo root
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

## Command map

```text
bh-clone init | sync [--with-profile] | ensure | up [--sync]
bh-clone use clone|main
bh-clone mcp print|json|install-grok|check
bh-clone doctor
```

## See also

- `docs/HARD_RULES.md` ← **必读**
- `references/chrome-devtools-mcp.md`
- `references/architecture.md`
- `docs/design.md`
- `AGENTS.md`
