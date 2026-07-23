# Design: bh-chrome-clone

## Problem

`browser-harness` can attach to the **main** Chrome, but Chrome 144+ often
shows **Allow remote debugging?** per connection. That breaks unattended
automation.

A dedicated Chrome started with `--remote-debugging-port` does **not** show
that popup, but a fresh profile has **no login cookies**.

Plain directory copy of the Chrome profile is **not enough**: cookie values
are encrypted; the clone process often drops `SESSDATA` and similar fields.

## Solution

```
┌─────────────────┐     CDP Network.getAllCookies      ┌──────────────────┐
│  Main Chrome    │ ─────────────────────────────────► │ cookie JSON file │
│  (daily use)    │     (decrypted values)             │ mode 0600        │
└─────────────────┘                                    └────────┬─────────┘
                                                                │
                     Storage.setCookies / Network.setCookie     │
┌─────────────────┐ ◄───────────────────────────────────────────┘
│  Clone Chrome   │
│  --remote-      │     BU_CDP_URL=http://127.0.0.1:9333
│  debugging-port │ ◄── browser-harness
└─────────────────┘
```

1. **Optional** rsync of profile (localStorage, prefs), excluding locks/caches.
2. **Required** cookie export from live main via CDP (needs Allow once).
3. Inject cookies into clone CDP session.
4. Point `BU_CDP_URL` at the clone.

## CLI map

| Command | Script | Purpose |
|---------|--------|---------|
| `bh-clone init` | `scripts/init.sh` | First-time full setup |
| `bh-clone sync` | `scripts/sync.sh` | Cookie export + inject |
| `bh-clone ensure` | `scripts/ensure.sh` | Start clone if down |
| `bh-clone use clone` | `scripts/use-clone.sh` | Default automation mode |
| `bh-clone use main` | `scripts/use-main.sh` | Live main attach |
| `bh-clone doctor` | `scripts/doctor.sh` | Health + bilibili probe |

## Security

- Cookie dump is real auth material → `chmod 600`, never commit.
- Clone profile is a second copy of session power → keep local only.
- Prefer domain-scoped exports for multi-user machines (future work).

## Non-goals

- Perfect forever clone (sessions expire).
- Cloud Browser Use profile sync (see upstream `profile-sync.md`).
- Replacing `opencli` site adapters.
