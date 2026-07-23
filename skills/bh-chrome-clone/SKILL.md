---
name: bh-chrome-clone
description: "Use a dedicated Chrome clone with synced login cookies for browser-harness automation — avoid Allow-remote-debugging popups on the main browser. Use when: browser-harness tasks need login state, unattended automation, bilibili/session sites, or user asks for Chrome clone/session twin / bh-clone."
---

# bh-chrome-clone

Reusable **session twin** for [browser-harness](https://github.com/browser-use/browser-harness):

- **Main Chrome** = daily browser (may prompt *Allow remote debugging?*)
- **Clone Chrome** = automation profile on CDP `:9333` (no Allow popup)
- Login is kept by **CDP cookie export → inject** (plain profile rsync alone is not enough)

CLI: `bh-clone` (install from this repo’s `cli/`).

## When to use

| Situation | Action |
|-----------|--------|
| Need logged-in automation without blocking the user | `bh-clone ensure` + `BU_CDP_URL=http://127.0.0.1:9333` |
| Clone returns 未登录 / API `isLogin:false` | `bh-clone sync` (user may click Allow **once** on main) |
| First machine setup | `bh-clone init` |
| Need the exact live tab strip | `bh-clone use main` (Allow may appear) |
| Public page / plain HTTP enough | Do **not** use browser; use fetch/curl |

## Prerequisites

```bash
# browser-harness
uv tool install --python 3.12 --upgrade browser-harness

# this skill's CLI
./install.sh   # from repo root → ~/.local/bin/bh-clone + skill link
```

Chrome/Chromium must be installed. Main profile default: `~/.config/google-chrome`.

## Agent workflow

### 1. Prefer clone for multi-step browser work

```bash
export PATH="$HOME/.local/bin:$PATH"
bh-clone ensure
# shell that sources env, or:
export BU_CDP_URL=http://127.0.0.1:9333

browser-harness <<'PY'
ensure_real_tab()
print(page_info())
PY
```

### 2. If login missing — resync (do not invent cookies)

```bash
bh-clone sync
# Optional full profile refresh (stops clone briefly):
# bh-clone sync --with-profile
```

Main Chrome may show **Allow remote debugging?** — ask the user to click **Allow once**. Do not spam reconnects.

### 3. Verify before scraping authenticated pages

```bash
bh-clone doctor
```

Or:

```bash
export BU_CDP_URL=http://127.0.0.1:9333
browser-harness <<'PY'
new_tab("https://api.bilibili.com/x/web-interface/nav")
wait_for_load()
print(js("document.body.innerText")[:300])
PY
```

Expect `"isLogin":true` for bilibili when cookies are valid.

### 4. Site data (bilibili etc.)

Prefer site adapters when available:

```bash
opencli bilibili search "query" -f json
opencli bilibili subtitle BVxxxx -f json
opencli bilibili summary BVxxxx -f json
```

Use browser-harness on the **clone** for UI flows adapters do not cover.

## Critical rules

1. **Never print or commit cookie dumps.** File default: `~/.config/browser-harness/main-cookies.json` (mode `600`).
2. **Do not** share the clone profile directory; it holds session power.
3. Prefer **clone** for automation; **main** only for live tabs / one-off human-paced work.
4. Cookie-only sync: sites that store auth only in localStorage may need `bh-clone sync --with-profile` or a manual login inside the clone.
5. This is a **Skill + CLI**, not an MCP. Browser control stays in browser-harness / chrome-devtools / opencli.

## Commands cheat sheet

```text
bh-clone init
bh-clone sync [--with-profile]
bh-clone ensure
bh-clone use clone|main
bh-clone doctor
bh-clone version
```

## Layout in this repo

```text
skills/bh-chrome-clone/SKILL.md   ← this file
cli/                              ← bh-clone implementation
references/                       ← design + verification notes
```

## See also

- Upstream harness: https://github.com/browser-use/browser-harness
- Design notes: `../../docs/design.md`
- Verified run log: `../../references/verification.md`
