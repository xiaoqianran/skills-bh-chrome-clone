# browser-harness（上游官方）

本仓库 **不内嵌** browser-harness 源码。新环境必须按 **官方仓库** 安装并注册 skill，再配合本仓库的 clone（`:9333`）。

## 官方地址（必读）

| 资源 | URL |
|------|-----|
| **GitHub 仓库** | https://github.com/browser-use/browser-harness |
| **安装 / 连接说明** | https://github.com/browser-use/browser-harness/blob/main/install.md |
| **Skill 正文** | `browser-harness skill`（安装 CLI 后打印） |
| **交互技能目录** | https://github.com/browser-use/browser-harness/tree/main/interaction-skills |
| **产品站** | https://browser-harness.com/ |

上游组织：[browser-use](https://github.com/browser-use)

> 配置不全面时，优先打开 **install.md**，不要只装本仓库。

---

## 与本仓库的关系

```text
官方 browser-harness          本仓库 bh-chrome-clone
─────────────────            ──────────────────────
CLI + skill + daemon         cookie-only → clone :9333
默认可附着用户 Chrome        BU_CDP_URL=http://127.0.0.1:9333
install.md 为准              HARD_RULES：不杀 MAIN
```

推荐新环境顺序：

1. **官方**：装 harness + 注册 `browser-harness` skill  
2. **本仓库**：`./install.sh` + `bh-clone up` + `export BU_CDP_URL=...:9333`  
3. 验证：`browser-harness --doctor` 与 `page_info()`

---

## 官方 Fast Path（新环境复制）

摘自 [install.md](https://github.com/browser-use/browser-harness/blob/main/install.md)，以 upstream 为准：

```bash
# 1) 安装 / 升级 CLI（必须 --python 3.12）
uv tool install --python 3.12 --upgrade --force browser-harness

# 2) 注册 Agent skill（Codex 示例；Claude/Grok 同理写到各自 skills 目录）
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills/browser-harness"
browser-harness skill > "${CODEX_HOME:-$HOME/.codex}/skills/browser-harness/SKILL.md"

# Grok:
mkdir -p ~/.grok/skills/browser-harness
browser-harness skill > ~/.grok/skills/browser-harness/SKILL.md

# Claude:
mkdir -p ~/.claude/skills/browser-harness
browser-harness skill > ~/.claude/skills/browser-harness/SKILL.md

# 3) 录音默认关（install.md：未明确时 default no）
browser-harness recordings disable

# 4) 本仓库：起 clone 并指向 harness（勿杀主浏览器）
bh-clone up
export BU_CDP_URL=http://127.0.0.1:9333
# 或: source ~/.config/browser-harness/env

# 5) 冒烟
browser-harness <<'PY'
ensure_real_tab()
print(page_info())
PY

browser-harness --doctor
```

本仓库也可一键执行上述 harness 部分：

```bash
./scripts/setup-browser-harness.sh
```

---

## 连接模型（官方支持）

见上游 skill：默认 daemon、`BU_NAME`、`BU_CDP_URL`、`BU_CDP_WS`、`start_remote_daemon(...)`。

本仓库默认：

```bash
export BU_CDP_URL=http://127.0.0.1:9333
```

- **不要**用 chrome-devtools `--auto-connect` 当默认自动化路径  
- MAIN 只读导出 cookie 见 [COOKIE_ONLY.md](COOKIE_ONLY.md) / [HARD_RULES.md](HARD_RULES.md)  
- 若不用 clone、直接附着日常 Chrome：用户须在  
  `chrome://inspect/#remote-debugging` 允许调试（官方 install.md「If Chrome Blocks It」）

---

## Cloud（可选）

本地 clone **不需要** Browser Use API key。  
需要云浏览器时见官方：

```bash
browser-harness auth login
# https://github.com/browser-use/browser-harness/blob/main/install.md
```

---

## 故障排查

| 现象 | 动作 |
|------|------|
| 无 `browser-harness` 命令 | 官方 install：`uv tool install --python 3.12 --upgrade --force browser-harness` |
| Agent 没有 browser-harness skill | 重新 `browser-harness skill > …/SKILL.md`，**重启** Agent 宿主 |
| daemon / 连不上 | `browser-harness --doctor`；确认 `BU_CDP_URL` 与 `bh-clone ensure` |
| 只装了本仓库没装上游 | **不完整** — 必须装官方 harness |

状态目录默认：`${XDG_CONFIG_HOME:-~/.config}/browser-harness`（可用 `BH_HOME` 覆盖，见官方 install.md）。
