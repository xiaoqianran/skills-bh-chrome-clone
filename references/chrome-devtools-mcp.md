# Use chrome-devtools MCP with the clone (no auto-connect)

Goal: **chrome-devtools-mcp does not attach to your daily Chrome**.  
It talks to the same **session twin** as browser-harness (`bh-clone` on `:9333`).

## Why

| Mode | Flag | Problem |
|------|------|---------|
| Auto-connect main | `--auto-connect` | Touches real tabs; may need Allow; fights daily use |
| Separate empty profile | `--userDataDir .../google-chrome-cdp` | No login cookies |
| **Clone CDP (recommended)** | `--browserUrl http://127.0.0.1:9333` | Shared login with harness; no Allow on clone |

## Prerequisites

```bash
bh-clone init    # once
bh-clone ensure  # start clone CDP
bh-clone sync    # when login expires
```

## Grok / MCP config (`~/.grok/config.toml`)

```toml
[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@latest",
    "--browserUrl",
    "http://127.0.0.1:9333",
]
enabled = true
startup_timeout_sec = 90
```

**Remove** `--auto-connect` and a separate `--userDataDir` for daily Chrome.

After editing config, **restart the MCP client / Grok session** so the server reloads.

## Startup order

```text
1. bh-clone ensure          # Chrome clone listening on :9333
2. (optional) bh-clone sync # cookies if needed
3. Start chrome-devtools MCP  # connects via browserUrl
4. Agent uses list_pages / click / ...
```

If MCP starts before the clone is up, connection fails — run `bh-clone ensure` first.

## Same cookies as browser-harness

Both use:

- Profile: `~/.config/browser-harness-chrome-clone`
- CDP: `http://127.0.0.1:9333`
- Cookie sync: `bh-clone sync`

So opencli/harness login state and chrome-devtools tools share one automation browser.
