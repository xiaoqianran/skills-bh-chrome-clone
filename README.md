# skills-bh-chrome-clone

**Agent Skill + CLI** — 把主 Chrome 的登录态同步到**独立自动化浏览器**（CDP `:9333`），同时给：

1. **[browser-harness](https://github.com/browser-use/browser-harness)**  
2. **[chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)**  

用，**不要**对日常主浏览器 `--auto-connect`。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 一张图

```text
                    ┌─────────────────────────┐
                    │  Main Chrome (日常)      │
                    │  登录 / 真标签           │
                    └───────────┬─────────────┘
                                │ CDP 导出 Cookie（可弹一次 Allow）
                                ▼
                    ┌─────────────────────────┐
                    │  Clone Chrome :9333      │
                    │  profile + 注入 Cookie   │
                    └───────────┬─────────────┘
                     ┌──────────┴──────────┐
                     ▼                     ▼
            browser-harness         chrome-devtools MCP
            BU_CDP_URL=...:9333     --browserUrl ...:9333
```

---

## 为什么

| 方式 | 登录态 | Allow 弹窗 | 适合 |
|------|--------|------------|------|
| 附着主 Chrome / `--auto-connect` | 有 | 常有 | 临时调试 |
| 空 profile | 无 | 无 | 匿名 |
| **本项目 Clone** | Cookie 同步后有 | **Clone 上无** | 无人值守 + 双客户端 |

> 只 `rsync` profile **不够**：磁盘 Cookie 加密，clone 常丢掉 `SESSDATA`。必须 **CDP 明文导出再注入**。

---

## 完整安装（从头到尾）

### 0. 依赖

- Google Chrome / Chromium  
- [uv](https://github.com/astral-sh/uv) + Python 3.12  
- `curl` `rsync` `bash` `python3`  
- （可选）Grok / 其他 MCP 宿主  

```bash
uv tool install --python 3.12 --upgrade browser-harness
```

### 1. 安装本仓库

```bash
git clone https://github.com/xiaoqianran/skills-bh-chrome-clone.git
cd skills-bh-chrome-clone
./install.sh
# → ~/.local/bin/bh-clone
# → ~/.grok/skills/bh-chrome-clone（及 codex/claude 若存在）
```

确保 `~/.local/bin` 在 `PATH` 中。

### 2. 首次建立 session twin

```bash
bh-clone init
# 主 Chrome 可能提示 Allow remote debugging — 点一次 Allow
bh-clone doctor
```

### 3. 配置 browser-harness

```bash
bh-clone up
export BU_CDP_URL=http://127.0.0.1:9333
# 或: source ~/.config/browser-harness/env

browser-harness <<'PY'
new_tab("https://www.bilibili.com/")
print(page_info())
PY
```

### 4. 配置 chrome-devtools MCP（关键）

**不要**再写 `--auto-connect` 连主浏览器。

```bash
bh-clone mcp print              # 查看 TOML
bh-clone mcp install-grok       # 写入 ~/.grok/config.toml
# 然后【重启 Grok / MCP 宿主】使配置生效
```

等价手写：

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

JSON 客户端：`bh-clone mcp json` 或 `cli/config/chrome-devtools.mcp.example.json`。

### 5. 日常

```bash
bh-clone up              # 确保 clone 在跑 + 写 harness env
# 登录过期：
bh-clone sync
# 或
bh-clone up --sync

bh-clone doctor          # CDP + harness 登录 + MCP 配置检查
```

---

## CLI 一览

```text
bh-clone init
bh-clone sync [--with-profile]
bh-clone ensure
bh-clone up [--sync]              # 双客户端就绪
bh-clone use clone|main

bh-clone mcp print|json|install-grok|check
bh-clone doctor
bh-clone version                  # 0.2.x
```

---

## 仓库结构

```text
skills-bh-chrome-clone/
├── skills/bh-chrome-clone/SKILL.md   # Agent Skill
├── cli/                              # bh-clone 实现
│   ├── bin/bh-clone
│   ├── lib/common.sh
│   ├── scripts/                      # init sync ensure up doctor mcp-config
│   └── config/                       # MCP / env 示例
├── references/                       # 架构 / 验证 / MCP 说明
├── docs/design.md
├── AGENTS.md
├── install.sh
└── README.md
```

---

## 双客户端对照

| | browser-harness | chrome-devtools MCP |
|--|-----------------|---------------------|
| 连接 | `BU_CDP_URL` | `--browserUrl` |
| 配置命令 | `bh-clone up` / `use clone` | `bh-clone mcp install-grok` |
| 目标 | 脚本化控制、CDP helpers | 列表页/点击/网络/性能工具 |
| 共用 | 同一 clone profile + `:9333` + Cookie 同步 | 同左 |

---

## 安全

- Cookie 文件：`~/.config/browser-harness/main-cookies.json`（**600**）  
- **勿提交** cookies / clone profile  
- Clone = 第二份登录钥匙，仅本机使用  

---

## 验证（曾实测）

见 [references/verification.md](references/verification.md)：

- clone CDP ready  
- bilibili `isLogin: true`  
- 搜索「清华学生如何学习」有真实结果  

---

## License

MIT
