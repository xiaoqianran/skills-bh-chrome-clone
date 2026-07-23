# Verification log (local)

Date: 2026-07-23  
Host: Linux + Google Chrome 150 + browser-harness 0.1.7 + bh-clone 0.1.0

## Results

| Step | Result |
|------|--------|
| `bh-clone version` | `bh-chrome-clone 0.1.0` |
| `bh-clone ensure` | clone CDP ready on `:9333` |
| `bh-clone use clone` | `BU_CDP_URL=http://127.0.0.1:9333` |
| Bilibili nav API | `"isLogin":true`, mid `3707026140039918` |
| Open bilibili home | OK |
| Search `清华学生如何学习` | OK; titles include 清华理科学霸 / 学习习惯 等 |
| `opencli bilibili subtitle` | Optional; may timeout if opencli browser bridge slow — not required for clone core |

## Commands used

```bash
bh-clone ensure
export BU_CDP_URL=http://127.0.0.1:9333
browser-harness <<'PY'
new_tab("https://api.bilibili.com/x/web-interface/nav")
wait_for_load()
print(js("document.body.innerText")[:400])
PY
```

## Note

Doctor may show `daemon alive FAIL` between reloads; a subsequent `browser-harness` call restarts the daemon. Trust the login API probe over a momentary doctor FAIL after `--reload`.
