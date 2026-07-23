# Agent notes — skills-bh-chrome-clone

## 用户偏好（本机 / 本仓库）

- **标签页：渐进式关闭。** 任务不再需要某个标签时，用 CDP `Target.closeTarget` **渐进关掉**，不必攒一大堆。  
- **内存相对够用**：可以多开 clone / 多标签做并行；但用完的页仍应顺手关，避免无意义堆积。  
- **不要**为了省内存去杀主 Chrome；只关 clone 上的 page target。  
- 关闭后至少保留 1 个可用标签（about:blank 或当前工作页），避免浏览器无页可挂。

## 上游 browser-harness（新环境必装）

本仓库 **不包含** harness 本体。新机器必须先装官方：

| | URL |
|--|-----|
| **GitHub** | https://github.com/browser-use/browser-harness |
| **install.md** | https://github.com/browser-use/browser-harness/blob/main/install.md |
| 本仓库对接说明 | [docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md) |
| 一键脚本 | `./scripts/setup-browser-harness.sh` |

只装 `bh-clone` 而没装上游 harness = **配置不完整**。  
装完后注册 `browser-harness` skill（`browser-harness skill > …/SKILL.md`），并 `export BU_CDP_URL=http://127.0.0.1:9333`。

## ⛔ HARD RULES + cookie-only（先读这个）

**完整条文：**
- [docs/HARD_RULES.md](docs/HARD_RULES.md) — 禁止事项（冲突时以它为准）
- [docs/COOKIE_ONLY.md](docs/COOKIE_ONLY.md) — 默认只复制 cookie 的模型
- [docs/BROWSER_HARNESS.md](docs/BROWSER_HARNESS.md) — 上游官方地址与安装

### 模型

```text
MAIN ──read getAllCookies──► JSON ──write setCookies──► CLONE :9333
```

- **MAIN**：只读源；进程与 profile **零改动**  
- **CLONE**：唯一可写、可杀、可重启  
- **失败**：导出失败就停（CLI 已打印标准说明），禁止杀 MAIN fallback  

### 主浏览器——绝对禁止

- **禁止** kill / 重启主 Chrome（含「为了开远程调试」）  
- **禁止** 删/改主 profile 的 Singleton*、Local State、Cookies、Storage  
- **禁止** 主 profile + `--remote-debugging-port`  
- **禁止** 在主浏览器上 deleteCookies / 清站点 / 写回 clone 数据  

### 你只应操作

| 对象 | 允许 |
|------|------|
| `bh-clone sync` / `init` | MAIN 只读导出 + CLONE 注入（默认 cookie-only） |
| `bh-clone ensure` / `up` | 只动 clone |
| cookie JSON | 读写但不打印、不提交 |
| MCP | `--browserUrl http://127.0.0.1:9333`，禁止 `--auto-connect` |

### 导出失败

```text
停 → 请用户 chrome://inspect/#remote-debugging Allow
   → 再 bh-clone sync
   → 禁止杀主浏览器
```

### 其它

- 不要默认 `--include-google`  
- 不要把 bilibili/某站登录当安装成功条件；用户没点名不要测站  
- 不要把 cookie 打进聊天

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
