# HARD RULES — 绝对禁止（Agent / 人类运维）

> **本文件优先级最高。** 与本仓库任何脚本、README 示例、故障排查建议冲突时，**以本文件为准**。  
> 违反下列条款会导致：日常主浏览器被杀、登录态丢失（含 grok.com / 银行 / 邮箱等）、用户数据不可恢复。

---

## 0. 一句话

**主 Chrome = 用户的日常浏览器。Agent 只能读 cookie（经 `bh-clone sync` 既定流程），绝不能杀、改、重启、锁、清主浏览器。**

默认模型是 **cookie-only**（详见 [COOKIE_ONLY.md](COOKIE_ONLY.md)）：

```text
MAIN ──read──► JSON ──write──► CLONE
```

没有第四步「修主浏览器」。导出失败就停。

自动化只允许操作 **clone**：

| | 主浏览器（MAIN） | 自动化 clone（TWIN） |
|--|------------------|----------------------|
| Profile | `~/.config/google-chrome`（或系统默认） | `~/.config/browser-harness-chrome-clone` |
| CDP | 仅用户本人点 Allow 时由 `sync` 短暂使用 | `http://127.0.0.1:9333` |
| 谁能动进程 | **仅用户本人** | `bh-clone ensure` / `kill_clone_chrome` 仅限 clone |

---

## 1. 对主浏览器（MAIN）——绝对禁止

下列操作 **一律禁止**。不得以「为了 init / sync / 打开远程调试 / doctor 失败 / 导出 cookie / 配置 MCP」为由执行。

### 1.1 进程与生命周期

- ❌ `kill` / `pkill` / `killall` / `SIGTERM` / `SIGKILL` **任何**主 Chrome / Chromium 进程  
- ❌ 结束「看起来像 chrome 的全部进程」再重拉（即使用 `--restore-last-session`）  
- ❌ 为「启用 remote debugging」而重启主浏览器  
- ❌ 用 `fuser -k`、杀端口等方式波及主浏览器正在使用的端口/进程  

### 1.2 Profile 与磁盘

- ❌ 删除或改写主 profile 下的 `SingletonLock` / `SingletonSocket` / `SingletonCookie`  
- ❌ 改写主 profile 的 `Local State`、`Preferences`、`Secure Preferences`（含「写 remote_debugging pref」）  
- ❌ 删除、清空、覆盖主 profile 的 `Cookies` / `Network/Cookies` / Local Storage / IndexedDB / Session  
- ❌ 向主 profile **写回** rsync、cookie JSON、clone 数据  
- ❌ `rm -rf` 主 profile 或其子目录  

### 1.3 CDP / 调试

- ❌ 给**默认主 profile** 加 `--remote-debugging-port=...` 强行重启  
- ❌ 在主浏览器上执行 `Network.deleteCookies` / `Storage.clearDataForOrigin` / 清站点数据  
- ❌ 把主浏览器当作「可随意销毁的测试实例」  

### 1.4 社会工程式绕过

- ❌ 「用户不在，我先杀了再配」  
- ❌ 「Chrome 150 默认 profile 不给 RDP，所以只能杀主浏览器」→ **应停下来问用户**，或只用文档规定的 **非默认 user-data-dir 临时副本**（且不得动主进程）  
- ❌ 「只是重启一下，登录还在」→ **假的**；强杀可丢 session / grok.com 等登录  

### 1.5 唯一允许的主浏览器交互

1. **用户本人**在主 Chrome 里登录、点 Allow、日常使用。  
2. `bh-clone sync` / `init` **仅通过 browser-harness 既定路径**从主 Chrome **只读导出** cookie（可能触发一次 Allow 弹窗 → **请用户点 Allow**，Agent 不得代杀浏览器）。  
3. 只读检查路径是否存在（例如 doctor 看 profile 目录）——**不改文件、不杀进程**。

若主 Chrome 未开远程调试、无法导出 cookie：

```text
正确：告知用户如何在 chrome://inspect/#remote-debugging 允许调试，
      或说明「本次只能先起 clone，登录态等你允许后再 sync」。
错误：kill 主 Chrome / 改 Local State / 删 Singleton* / 带 --remote-debugging-port 重启主 profile。
```

---

## 2. 对 clone（TWIN）——允许范围

- ✅ `bh-clone ensure` / `up` 启动 **仅** `user-data-dir=browser-harness-chrome-clone` 的进程  
- ✅ `kill_clone_chrome` **仅**匹配 clone profile 的进程  
- ✅ 对 `:9333` 注入 cookie、清理 clone 上的 Google 系 cookie（默认安全策略）  
- ✅ 写 `~/.config/browser-harness/env`、`main-cookies.json`（权限 600）  
- ✅ `bh-clone mcp install-grok` 改 **Grok MCP 配置**（指向 clone，不是主浏览器）

Clone 仍是「第二把登录钥匙」：

- ❌ 不要把 clone cookie / `main-cookies.json` 打进聊天、日志、git  
- ❌ 默认不要 `--include-google`  

---

## 3. Cookie 与站点登录

- ❌ 打印 / 提交 / 粘贴 `~/.config/browser-harness/main-cookies.json` 内容  
- ❌ 默认同步 Google 系 cookie（见 `cookie_filter.py`）；除非用户**书面明确**接受风险并要求 `--include-google`  
- ❌ 把 bilibili / grok / 任意站点「是否登录」当成 **安装是否成功** 的唯一标准  
  - `bh-clone doctor` 里 bilibili 探针失败 **≠** 配置失败  
  - 用户未要求测某站时，**不要**强行打开、登录、断言该站  

---

## 4. MCP / 客户端

- ❌ chrome-devtools 使用 `--auto-connect` 附着主浏览器作为默认自动化路径  
- ✅ 必须：`--browserUrl http://127.0.0.1:9333`（或当前 `BH_CDP_PORT`）  
- ✅ 先 `bh-clone ensure`，再让 MCP 宿主加载  

---

## 5. 事故类操作回顾（禁止重演）

下列组合曾导致 **主浏览器登录丢失**，列为永久反面教材：

1. 发现主 Chrome 无 `DevToolsActivePort`  
2. Agent **强杀全部 chrome 进程**  
3. 删除主 profile Singleton*  
4. 用主 profile + `--remote-debugging-port` 重启  
5. 用户发现 grok.com 等登录消失  

**正确替代：**

- 只操作 clone profile + `:9333`  
- cookie 导出失败 → **停、说明、等用户**  
- 需要非默认目录临时 Chrome 做导出时：使用 **独立** `user-data-dir`（副本），**禁止**结束用户正在用的主进程；用完只杀该临时实例  

---

## 6. Agent 检查清单（动手前）

在跑任何 shell 之前自问：

1. 这条命令会匹配到 **主** Chrome 进程吗？→ 有则 **不做**  
2. 会写 `~/.config/google-chrome` 吗？→ 除用户明确要求外 **不做**  
3. 是否「为了方便配置」要重启用户日常浏览器？→ **不做，改问用户**  
4. 用户是否要求登录/测试某个网站？→ 未要求则 **不测、不登录**  
5. 是否会把 cookie 明文打进对话？→ **不做**

---

## 7. 文档索引

| 文档 | 用途 |
|------|------|
| **本文件** | 禁止事项权威来源 |
| [AGENTS.md](../AGENTS.md) | Agent 默认策略（必须遵守本文件） |
| [skills/bh-chrome-clone/SKILL.md](../skills/bh-chrome-clone/SKILL.md) | Skill 入口 |
| [README.md](../README.md) | 安装与日常命令 |
| [architecture.md](../references/architecture.md) | 数据流 |

---

**维护要求：** 任何新增脚本若可能触及主浏览器进程或 profile，必须在 PR 中引用本文件并说明为何不违规；默认答案应是「做不到就报错退出，留给用户」。
