# chrome-devtools MCP + bh-clone

## Correct

```bash
bh-clone ensure
bh-clone mcp install-grok   # or paste: bh-clone mcp print
# restart MCP host
```

MCP args must include:

```text
--browserUrl http://127.0.0.1:9333
```

## Incorrect

```text
--auto-connect
--userDataDir /path/to/empty-or-main-adjacent-profile
```

## Order

```text
bh-clone ensure  →  MCP starts  →  agent tools
```

If MCP starts first, connection fails until clone is up.

## Cursor / Claude Desktop / other JSON hosts

```bash
bh-clone mcp json
```

Or use `cli/config/chrome-devtools.mcp.example.json`.
