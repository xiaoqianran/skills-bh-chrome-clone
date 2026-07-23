# skills-bh-chrome-clone

用**第二个 Chrome**（自动化专用）干活，**不要动你日常上网的那个 Chrome**。

---

## 30 秒看懂

你日常用的 Chrome（里面登了知乎、各种账号）叫 **主浏览器**。

如果让机器人**直接操作主浏览器**，会：

- 经常弹「允许远程调试」
- 和你手边标签打架
- 搞不好还把登录搞丢（我们踩过坑）

所以本项目做了这件事：

```text
主浏览器（你用）  ──复制 Cookie──►  第二个浏览器 clone（机器人用）
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                  browser-harness                  chrome-devtools
                  （写脚本控制）                   （在 Grok 里点网页）
```

- **主浏览器**：只负责你自己登录；偶尔允许一次「远程调试」以便复制 Cookie  
- **clone 浏览器**：开在 `http://127.0.0.1:9333`，给自动化用  
- **browser-harness** 和 **chrome-devtools** 连的是**同一个** clone，不是两个浏览器  

---

## 和你有关的三个名字

| 名字 | 是什么 | 你要不要装 |
|------|--------|------------|
| **本仓库 `bh-clone`** | 复制 Cookie、启动 clone、写配置的小工具 | ✅ 要 |
| **browser-harness** | 官方「用 Python 控制浏览器」的工具 | ✅ 要（另一个 GitHub） |
| **chrome-devtools MCP** | 让 Grok 等 AI 直接点网页的插件 | 可选 |

browser-harness **不在本仓库里**，官方地址：

- 仓库：https://github.com/browser-use/browser-harness  
- 安装说明：https://github.com/browser-use/browser-harness/blob/main/install.md  

更细的对接说明：[docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md)

---

## 新电脑怎么装（按顺序做）

### 你需要先有

- Google Chrome  
- [uv](https://github.com/astral-sh/uv)（用来装 Python 工具）  
- 基本命令：`bash`、`curl`、`python3`  

### 一步安装（推荐）

```bash
git clone https://github.com/xiaoqianran/skills-bh-chrome-clone.git
cd skills-bh-chrome-clone
./install.sh
```

这一步会：

1. 安装命令 `bh-clone`  
2. 装上本仓库的 AI skill  
3. **尽量**顺带装好官方 browser-harness（需要机器上有 `uv`）  

如果只想装本仓库、暂时不装 harness：

```bash
BH_SKIP_HARNESS=1 ./install.sh
# 以后再装 harness：
./scripts/setup-browser-harness.sh
```

保证 `~/.local/bin` 在 PATH 里（装完能直接敲 `bh-clone`）。

### 第一次：把登录态拷到 clone

1. 打开你的**主 Chrome**，确认想同步的网站已经登录（比如知乎）。  
2. 在主 Chrome 地址栏打开：

   `chrome://inspect/#remote-debugging`

3. 勾选 **Allow remote debugging for this browser instance**，弹窗点 **Allow**。  
4. 终端执行：

```bash
bh-clone init
# 以后登录过期只跑：
# bh-clone sync
```

成功含义：Cookie 从主浏览器**读出来**，写进 clone。  
**不会**关掉你的主浏览器，也**不会**改主浏览器里的文件。

如果失败：多半是第 2–3 步没勾好，再勾一次后执行 `bh-clone sync`。

### 日常怎么用

```bash
# 1) 保证 clone 在跑
bh-clone up

# 2) 告诉 harness 连 clone（不是主浏览器）
source ~/.config/browser-harness/env
# 里面是：export BU_CDP_URL=http://127.0.0.1:9333

# 3) 试一下
browser-harness <<'PY'
ensure_real_tab()
print(page_info())
PY
```

### 想在 Grok 里用 chrome-devtools（可选）

```bash
bh-clone mcp install-grok
# 然后重启 Grok，让配置生效
```

配置要点：连 `http://127.0.0.1:9333`，**不要**写 `--auto-connect`（那是去连主浏览器）。

---

## 你最常用的命令

| 命令 | 干什么 |
|------|--------|
| `bh-clone up` | 启动 clone，写好环境变量 |
| `bh-clone sync` | 从主浏览器**重新复制** Cookie（登录过期时） |
| `bh-clone doctor` | 检查是否正常 |
| `bh-clone ensure` | 只确保 clone 在跑 |
| `bh-clone mcp install-grok` | 给 Grok 配 chrome-devtools |

```bash
bh-clone init          # 第一次
bh-clone sync          # 以后同步 Cookie
bh-clone up            # 日常启动
bh-clone doctor        # 体检
```

---

## 安全（很重要，三句话）

1. **机器人只准动 clone**，不准杀、不准重启、不准改你的**主 Chrome**。  
2. 复制 Cookie 时，主浏览器最多让你点一次 **Allow**；点不了就停，**不会**「强行重启主浏览器」。  
3. **默认不复制 Google / YouTube / Gmail 等账号 Cookie**，降低主号进自动化环境的风险。

完整禁止清单：[docs/HARD_RULES.md](docs/HARD_RULES.md)

---

## 常见问题

**Q：browser-harness 和 chrome-devtools 是不是两个浏览器？**  
A：不是。都连 **同一个 clone（端口 9333）**。

**Q：为什么不直接控制我正在用的 Chrome？**  
A：会弹窗、抢标签，还有丢登录的风险。clone 是专用的「机器人浏览器」。

**Q：只装了这个仓库，没装 browser-harness 行吗？**  
A：可以启动 clone、配 MCP，但**脚本控制浏览器**要用官方 harness，请看上面的 GitHub 链接。

**Q：`doctor` 说 bilibili 没登录，是不是装失败了？**  
A：不是。那只是可选探测；你没要求同步 B 站就不影响。

**Q：Google 搜索在 clone 里要验证码？**  
A：常见（机房 IP）。可换 DuckDuckGo，或主浏览器里搜完把链接给 AI。

---

## 文档索引（按需点开）

| 文档 | 内容 |
|------|------|
| [docs/HARD_RULES.md](docs/HARD_RULES.md) | 绝不能动主浏览器的规定 |
| [docs/COOKIE_ONLY.md](docs/COOKIE_ONLY.md) | 默认「只复制 Cookie」是什么意思 |
| [docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md) | 官方 harness 怎么装、怎么对接 |
| [docs/RL_SEARCH_EVAL_AND_NOTES.md](docs/RL_SEARCH_EVAL_AND_NOTES.md) | 强化学习资料检索笔记 + 两工具速度对比 |
| [AGENTS.md](AGENTS.md) | 给 AI Agent 看的简短规则 |

---

## 开发者：跑测试

```bash
bash cli/tests/run-tests.sh
```

当前 CLI 版本：见 `bh-clone version`（源码里 `BH_CLONE_VERSION`）。

---

## License

MIT
