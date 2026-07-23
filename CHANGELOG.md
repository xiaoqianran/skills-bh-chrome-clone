# Changelog

## 0.2.7

### Multi-instance / harness multi-open

- Problem: pinning `BU_CDP_URL=:9333` made all harness jobs share one Chrome
- Fix: **pool** of local clones — each worker has own profile, CDP port, `BU_NAME`
- Commands: `bh-clone pool start N|list|stop|env|sync`
- Flags: `--instance NAME --port N` on ensure/up/sync; `--inject-only` for pool sync
- Env files: `~/.config/browser-harness/env` and `env.w1`, `env.w2`, …
- Docs: [docs/MULTI_INSTANCE.md](docs/MULTI_INSTANCE.md)

## 0.2.6

### Code quality + tests

- Extract `cli/lib/cookie_io.py` (normalize/export/inject helpers; no secret logging)
- Rewrite `kill_clone` via `list_clone_pids` (clearer, testable)
- Expand `is_main_profile_path` (chromium paths); shared `BH_CLONE_VERSION`
- Slim `sync.sh` harness snippets to use cookie_io
- Tests: expanded `test_cookie_filter.py`, new `test_guards.sh`, `run-tests.sh`

## 0.2.5

### Safety hardening (MAIN never collateral)

- `kill_clone_chrome`: **remove `fuser -k` by port** (could kill MAIN if ports collide)
- Kill only PIDs whose cmdline contains clone `user-data-dir=` (double-checked)
- `bh-clone use main` requires `BH_ALLOW_USE_MAIN=1` (default refuse; still never kills)
- `ensure` refuses MAIN as clone profile; always passes `--user-data-dir=CLONE`
- HARD_RULES updated to document no port-based kill

## 0.2.4

### Docs / new-env harness

- Pin **upstream** browser-harness GitHub in-repo so new machines are not incomplete:
  - https://github.com/browser-use/browser-harness
  - https://github.com/browser-use/browser-harness/blob/main/install.md
- Add [docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md) + `scripts/setup-browser-harness.sh`
- `./install.sh` runs harness setup by default (`BH_SKIP_HARNESS=1` to skip)
- README / AGENTS / Skill / env.example link official install.md

## 0.2.3

### Cookie-only model (default)

- Default path is **only copy cookies**: MAIN read → JSON → CLONE write
- `init` / `sync` no longer require full profile rsync; empty clone dir if missing
- `--with-profile` remains optional (rsync main→clone; still never stops MAIN)
- Export failure → `die_main_cookie_export_failed` standard message (Allow in MAIN; never kill MAIN)
- Guards: `assert_main_clone_distinct`, refuse strip/kill/pref-write on MAIN
- Docs: [docs/COOKIE_ONLY.md](docs/COOKIE_ONLY.md); help/SKILL/AGENTS/README aligned
- Version **0.2.3**

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
