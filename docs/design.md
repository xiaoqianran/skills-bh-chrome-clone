# Design

## Goals

1. Authenticated automation without blocking the user's daily Chrome.
2. One session twin for **browser-harness** and **chrome-devtools-mcp**.
3. Reusable CLI + Agent Skill (not a new MCP server).

## Non-goals

- Perfect browser fingerprint cloning.
- Replacing opencli site adapters.
- Auto-connecting to the main browser by default.

## Data flow

1. Optional: rsync main profile → clone (localStorage, prefs).
2. Required: CDP `Network.getAllCookies` on main → JSON (0600).
3. CDP `Storage.setCookies` on clone.
4. Clients attach to `http://127.0.0.1:9333`.

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
