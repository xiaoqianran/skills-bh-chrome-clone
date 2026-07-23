# Architecture (short)

```
Main Chrome  --CDP getAllCookies-->  cookies.json (0600)
                                         |
                                         v
Clone Chrome (:9333)  <-- Storage.setCookies --
        ^
        |  BU_CDP_URL
 browser-harness / agents
```

Why not only rsync profile?

- Cookie values are encrypted on disk.
- Clone process often drops `SESSDATA` after failed decrypt.
- CDP export yields **plaintext** values that inject reliably on the same machine.
