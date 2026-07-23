# Design

## Goals

1. Authenticated automation without blocking the user's daily Chrome.
2. One session twin for **browser-harness** and **chrome-devtools-mcp**.
3. Reusable CLI + Agent Skill (not a new MCP server).

## Non-goals

- Perfect browser fingerprint cloning.
- Replacing opencli site adapters.
- Auto-connecting to the main browser by default.
- **Managing / restarting / debugging the user's daily main Chrome process.**

## Safety non-negotiables

See **[HARD_RULES.md](HARD_RULES.md)**. Agents and scripts must:

- Never kill or relaunch the main Chrome profile.
- Never rewrite main profile locks, Local State, or cookies.
- Only automate against the clone (`:9333` / `browser-harness-chrome-clone`).
- Treat site-login probes (e.g. bilibili in doctor) as optional, not install gates.

## Data flow (cookie-only default)

1. Required: CDP `Network.getAllCookies` on **MAIN** (read-only) → JSON (0600).  
   On failure: stop and instruct user — **never** kill MAIN.
2. Required: CDP `Storage.setCookies` on **CLONE** only.
3. Optional: rsync main → clone (`--with-profile`) for localStorage/prefs (still never stops MAIN).
4. Clients attach to `http://127.0.0.1:9333`.

See [COOKIE_ONLY.md](COOKIE_ONLY.md).

## Why CDP cookie inject

Chrome encrypts cookie values on disk. A cold clone often drops `SESSDATA`.
CDP export returns decrypted values on the same machine; inject is reliable.

## Client attachment

| Client | Mechanism |
|--------|-----------|
| browser-harness | env `BU_CDP_URL` |
| chrome-devtools-mcp | CLI flag `--browserUrl` (not `--auto-connect`) |

## Failure modes

| Symptom | Fix |
|---------|-----|
| Allow popup on main | Expected during `sync`; click once |
| MCP cannot connect | `bh-clone ensure` then restart MCP host |
| isLogin false | `bh-clone sync` |
| Still auto-connect main | `bh-clone mcp install-grok` |
