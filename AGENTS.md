# Agent notes — skills-bh-chrome-clone

## ⛔ HARD RULES（先读这个）

**完整条文：[docs/HARD_RULES.md](docs/HARD_RULES.md) — 与任何其他说明冲突时以它为准。**

### 主浏览器（用户日常 Chrome）——绝对禁止

- **禁止** kill / pkill / killall / SIGTERM / SIGKILL 主 Chrome / Chromium  
- **禁止** 为开远程调试、sync、init、doctor 而**重启**主浏览器  
- **禁止** 删除或改写主 profile 的 `Singleton*`、`Local State`、`Preferences`、Cookies / Storage  
- **禁止** 向主 profile 写回数据；**禁止**在主浏览器上 `deleteCookies` / 清站点数据  
- **禁止** 用主 profile + `--remote-debugging-port` 强行拉起「调试版日常浏览器」  

主浏览器登录态（含 **grok.com**、邮箱、银行等）属于用户财产。  
**强杀主 Chrome = 可导致登录全部丢失且不可从本仓库恢复。**

### 你只应操作

| 对象 | 路径 / 端口 | 允许 |
|------|-------------|------|
| **Clone only** | `~/.config/browser-harness-chrome-clone` | ensure / sync 注入 / kill_clone |
| **Clone CDP** | `http://127.0.0.1:9333` | harness + chrome-devtools |
| **Cookie 文件** | `~/.config/browser-harness/main-cookies.json` | 读写但不打印、不提交 |
| **主 Chrome** | 默认 profile | 仅 `bh-clone sync` 只读导出；Allow 弹窗 → **请用户点** |

### 导出 cookie 失败时

```text
停下来 → 告诉用户如何 Allow remote debugging
      → 或先只 bh-clone ensure 起 clone
      → 禁止杀主浏览器「曲线救国」
```

### 其它

- 不要把 cookie 内容打进聊天  
- 不要默认 `--include-google`  
- **不要**把 bilibili / 某站登录当成安装成功条件；用户没点名就不要测站、不要逼登录  
- chrome-devtools：**禁止** `--auto-connect` 主浏览器；必须 `--browserUrl http://127.0.0.1:9333`

---

## What this is

Session twin for authenticated browser automation:

- **CLI `bh-clone`**: copies login cookies into a dedicated Chrome on CDP `:9333`
- **Skill `bh-chrome-clone`**: when/how to use it
- **Clients**:
  - **browser-harness** via `BU_CDP_URL=http://127.0.0.1:9333`
  - **chrome-devtools MCP** via `--browserUrl http://127.0.0.1:9333` (never `--auto-connect` main)

## Default agent policy

1. Prefer clone for multi-step / unattended work.
2. Before tools: `bh-clone ensure` (or `bh-clone up`).
3. If login fails: `bh-clone sync`（**请用户**在主 Chrome 上点 Allow；**不要**杀主浏览器）.
4. Do not dump cookie file contents into chat.
5. Public pages → curl/fetch; browser only when interaction/login needed.
6. Never touch main Chrome process or profile (see HARD_RULES).

## Commands

```bash
bh-clone init | sync | ensure | up [--sync]
bh-clone use clone|main
bh-clone mcp print | install-grok | check
bh-clone doctor
```

`doctor` 里 bilibili 探针失败 **不等于** 配置失败，除非用户要做 B 站自动化。
