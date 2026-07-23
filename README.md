# skills-bh-chrome-clone

**Agent Skill + CLI** for a **Chrome session twin** used with [browser-harness](https://github.com/browser-use/browser-harness).

> 把「主 Chrome 登录态」同步到「自动化 Clone（CDP `:9333`）」，免去主浏览器反复 **Allow remote debugging?** 弹窗。

| 形态 | 说明 |
|------|------|
| **Skill** | `skills/bh-chrome-clone/SKILL.md` — 教 Agent 何时 sync / ensure / 用 clone |
| **CLI** | `bh-clone` — 可复用脚本（非 MCP） |
| **不是** | 完整克隆浏览器指纹；不是 MCP server |

## Why Skill, not MCP?

- 低频运维流水线（init/sync），不是原子 click/fill。
- Cookie 同步副作用大，适合显式 CLI + Agent 规范。
- 真正的页面控制继续用 browser-harness / chrome-devtools / opencli。

## Verified (2026-07-23)

Local retest passed:

- `bh-clone ensure` → CDP `:9333` ready  
- Bilibili API `"isLogin": true`  
- Search `清华学生如何学习` returned real video titles on clone  

Details: [references/verification.md](references/verification.md)

## Quick start

### Dependencies

```bash
# Chrome/Chromium installed
uv tool install --python 3.12 --upgrade browser-harness
```

### Install this repo

```bash
git clone https://github.com/xiaoqianran/skills-bh-chrome-clone.git
cd skills-bh-chrome-clone
./install.sh
# ensures ~/.local/bin/bh-clone and links skill into ~/.grok/skills (and ~/.codex/skills if present)
```

### First-time session twin

```bash
bh-clone init          # profile rsync + cookie sync (main may ask Allow once)
bh-clone doctor        # should show bilibili isLogin when cookies valid
```

### Daily automation

```bash
bh-clone ensure
export BU_CDP_URL=http://127.0.0.1:9333   # or: source ~/.config/browser-harness/env

browser-harness <<'PY'
new_tab("https://www.bilibili.com/")
print(page_info())
PY
```

### Login expired

```bash
bh-clone sync
# full profile refresh:
bh-clone sync --with-profile
```

## CLI

```text
bh-clone init
bh-clone sync [--with-profile]
bh-clone ensure
bh-clone use clone|main
bh-clone doctor
bh-clone version
```

## Layout

```text
skills-bh-chrome-clone/
├── skills/bh-chrome-clone/SKILL.md   # Agent skill
├── cli/                              # bh-clone implementation
│   ├── bin/bh-clone
│   ├── lib/common.sh
│   └── scripts/
├── references/                       # architecture + verification
├── docs/                             # design notes
├── install.sh                        # CLI + skill install
└── README.md
```

## Security

- Cookie dump: `~/.config/browser-harness/main-cookies.json` (**mode 600**, gitignored patterns in `cli/.gitignore`)
- Never commit cookies or profile copies
- Clone profile is a second set of session keys — keep local

## How it works

```text
Main Chrome  --CDP Network.getAllCookies-->  cookies.json
                                                 |
Clone :9333  <-- Storage.setCookies -------------+
     ^
     | BU_CDP_URL
browser-harness
```

Plain `rsync` of the profile often **drops** encrypted `SESSDATA`. CDP inject fixes that.

See [docs/design.md](docs/design.md) and [references/architecture.md](references/architecture.md).

## Agent install (manual)

Copy or symlink the skill:

```bash
mkdir -p ~/.grok/skills
ln -sfn "$PWD/skills/bh-chrome-clone" ~/.grok/skills/bh-chrome-clone
```

## License

MIT
