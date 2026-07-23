# Architecture (short)

```
Main Chrome  --CDP getAllCookies-->  cookies.json (0600)
                                         |
                                         v
Clone Chrome (:9333)  <-- Storage.setCookies --
        ^
        |--------------------+
        |                    |
 BU_CDP_URL           --browserUrl
 browser-harness      chrome-devtools MCP
```

Why not only rsync profile?

- Cookie values are encrypted on disk.
- Clone process often drops `SESSDATA` after failed decrypt.
- CDP export yields **plaintext** values that inject reliably on the same machine.

Why not chrome-devtools `--auto-connect`?

- Attaches to daily Chrome → Allow popups, tab fights, riskier for agents.
- Twin CDP keeps automation isolated while reusing login via cookie sync.

## Hard boundary: main vs clone

```
MAIN  ~/.config/google-chrome          → human only; sync may READ cookies
CLONE ~/.config/browser-harness-chrome-clone + :9333 → automation only
```

**Never** kill/restart/rewrite MAIN to make tooling work.  
If CDP export needs a non-default profile, use a **temporary copy** user-data-dir — do **not** stop the user's live main browser.

Full ban list: [docs/HARD_RULES.md](../docs/HARD_RULES.md).
