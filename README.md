# skills-bh-chrome-clone

**Agent Skill + CLI** — 把主 Chrome 的登录态同步到**独立自动化浏览器**（CDP `:9333`），同时给：

1. **[browser-harness](https://github.com/browser-use/browser-harness)**（**上游官方**，本仓库不内嵌；安装见 [install.md](https://github.com/browser-use/browser-harness/blob/main/install.md)）  
2. **[chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)**  

用，**不要**对日常主浏览器 `--auto-connect`。

| 上游 | 地址 |
|------|------|
| browser-harness 仓库 | https://github.com/browser-use/browser-harness |
| browser-harness 安装 | https://github.com/browser-use/browser-harness/blob/main/install.md |
| 本仓库如何对接 harness | [docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md) |

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

> **新环境注意：** 只 clone 本仓库不够。必须同时按上游装好  
> **[browser-use/browser-harness](https://github.com/browser-use/browser-harness)**  
> （[install.md](https://github.com/browser-use/browser-harness/blob/main/install.md)）。  
> 详见 [docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md)。

### 0. 依赖

- Google Chrome / Chromium  
- [uv](https://github.com/astral-sh/uv) + Python 3.12  
- `curl` `rsync` `bash` `python3`  
- （可选）Grok / 其他 MCP 宿主  
- **上游：** [browser-harness](https://github.com/browser-use/browser-harness)

### 1. 安装本仓库（会尝试配置上游 harness）

```bash
git clone https://github.com/xiaoqianran/skills-bh-chrome-clone.git
cd skills-bh-chrome-clone
./install.sh
# → ~/.local/bin/bh-clone
# → ~/.grok/skills/bh-chrome-clone（及 codex/claude 若存在）
# → 默认再跑 ./scripts/setup-browser-harness.sh（官方 harness + skill）
#    跳过 harness：BH_SKIP_HARNESS=1 ./install.sh
```

确保 `~/.local/bin` 在 `PATH` 中。

仅补装 / 重装上游 harness：

```bash
./scripts/setup-browser-harness.sh
# 等价于官方:
#   uv tool install --python 3.12 --upgrade --force browser-harness
#   browser-harness skill > ~/.codex/skills/browser-harness/SKILL.md  # 等
# 文档: https://github.com/browser-use/browser-harness/blob/main/install.md
```

### 2. 首次建立 session twin（cookie-only）

```bash
bh-clone init
# 默认只复制 cookie，不杀/不改主浏览器
# 若导出失败：在主 Chrome 打开 chrome://inspect/#remote-debugging 点 Allow，再 bh-clone sync
# 可选全量 profile：bh-clone init --with-profile
bh-clone doctor
```

### 3. 配置 browser-harness → 指向 clone

上游 skill / daemon 的用法以官方为准：  
https://github.com/browser-use/browser-harness  

本仓库侧只负责把 **CDP 指到 clone**（官方支持 `BU_CDP_URL`）：

```bash
bh-clone up
export BU_CDP_URL=http://127.0.0.1:9333
# 或: source ~/.config/browser-harness/env

browser-harness <<'PY'
ensure_real_tab()
print(page_info())
PY
browser-harness --doctor
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

### 6. 多开（harness 并行，不抢同一个浏览器）

只绑一个 `:9333` 时，所有 harness 都打同一台 clone，**看起来像「多开没了」**。  
本地真并行需要多份 clone（或官方 cloud 浏览器）：

```bash
bh-clone pool start 2      # w1=:9333  w2=:9334，各自 profile + BU_NAME
bh-clone pool sync         # Cookie 导出一次，注入所有 worker
bh-clone pool list
bh-clone pool env          # 打印并行示例
```

```bash
# 终端 A
source ~/.config/browser-harness/env.w1
browser-harness <<'PY'
new_tab("https://www.zhihu.com/")
print(page_info())
PY

# 终端 B（同时）
source ~/.config/browser-harness/env.w2
browser-harness <<'PY'
new_tab("https://duckduckgo.com/")
print(page_info())
PY
```

详见 [docs/MULTI_INSTANCE.md](docs/MULTI_INSTANCE.md)。

### Google 账号：默认不同步

`bh-clone sync` **默认排除 Google 系 Cookie**（`google.com` / `youtube.com` / `gmail.com` / `googleapis.com` 等），  
并在注入后尝试 **清除 clone 上已有的 Google 系 Cookie**，降低主号进自动化环境的风险。

```bash
# 额外排除其它域名
BH_EXCLUDE_DOMAINS=example.com,foo.com bh-clone sync

# 不推荐：强制包含 Google（需自担账号风险）
# bh-clone sync --include-google
```

Google 相关操作请用主 Chrome 手动完成，或临时 `bh-clone use main`，不要把主 Google 会话拷进 twin。

---

## CLI 一览

```text
bh-clone init [--with-profile]    # 默认 cookie-only
bh-clone sync [--instance N] [--port P] [--inject-only] ...
bh-clone ensure [--instance N] [--port P]
bh-clone up [--sync] [--instance N]
bh-clone pool start N|list|stop|env|sync   # 本地多开
bh-clone use clone|main

bh-clone mcp print|json|install-grok|check
bh-clone doctor
bh-clone version                  # 0.2.7
```

### 跑测试

```bash
bash cli/tests/run-tests.sh
# 或: python3 cli/tests/test_cookie_filter.py && bash cli/tests/test_guards.sh && bash cli/tests/smoke_cli.sh
```

---

## 仓库结构

```text
skills-bh-chrome-clone/
├── docs/HARD_RULES.md                # ⛔ 绝对禁止事项（Agent 必读）
├── docs/COOKIE_ONLY.md               # 默认只复制 cookie 模型
├── docs/BROWSER_HARNESS.md           # 上游 harness 官方地址与新环境配置
├── scripts/setup-browser-harness.sh  # 按官方 install.md 装 harness + skill
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

### ⛔ 主浏览器绝对禁止（Agent / 脚本）

**权威全文：[docs/HARD_RULES.md](docs/HARD_RULES.md)**（与任何示例冲突时以它为准）

| 禁止 | 说明 |
|------|------|
| 杀 / 重启主 Chrome | 会导致 grok.com 等**日常登录丢失**，且不可从本仓库恢复 |
| 删主 profile `Singleton*` | 逼退日常浏览器 |
| 改主 profile `Local State` / Cookies / Storage | 破坏用户数据 |
| 主 profile + `--remote-debugging-port` 强行重启 | Chrome 新版本会拒，且伤会话 |
| 在主浏览器上清 cookie | 只允许对 **clone** 注入/过滤 |

主浏览器 **只**允许：用户本人使用；`bh-clone sync` 只读导出 cookie（Allow 弹窗由**用户**点）。  
导出失败 → **停下来告诉用户**，禁止「杀主浏览器曲线救国」。

自动化 **只**碰：

- profile：`~/.config/browser-harness-chrome-clone`  
- CDP：`http://127.0.0.1:9333`  

`bh-clone doctor` 里 bilibili 未登录 **不等于** 安装失败。

---

## 验证（曾实测）

见 [references/verification.md](references/verification.md)（**可选**场景，非安装必过门槛）：

- clone CDP ready  
- bilibili `isLogin: true`（仅当你在测 B 站登录时）  
- 搜索「清华学生如何学习」有真实结果  

---

## License

MIT
