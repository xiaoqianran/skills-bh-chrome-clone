# 多开：browser-harness 并行不抢同一个浏览器

## 问题

配置 `BU_CDP_URL=http://127.0.0.1:9333` 之后，**所有** harness 进程都连**同一个** clone。

官方也写了：Local Chrome 是一份共享浏览器，并行任务会抢标签/焦点。

所以不是 harness「不能多开」，而是 **只绑了一个 CDP 端点** 时，多开会变成「多个客户端打一台浏览器」。

## 解法（本仓库）

为每个 worker 起 **独立 clone**：

| 项 | worker w1 | worker w2 |
|----|-----------|-----------|
| Chrome profile | `~/.config/browser-harness-chrome-clone-w1` | `...-w2` |
| CDP 端口 | 9333 | 9334 |
| harness `BU_NAME` | `clone-w1` | `clone-w2` |
| env 文件 | `~/.config/browser-harness/env.w1` | `env.w2` |

每个 worker = 独立 Chrome 进程 + 独立 harness daemon。

**仍不碰主浏览器。**

## 用法

```bash
# 启动 2 个自动化浏览器
bh-clone pool start 2

# 把主浏览器 Cookie 导出一次，注入到所有 worker
bh-clone pool sync

# 查看
bh-clone pool list
```

并行（两个终端）：

```bash
# 终端 A — 知乎
source ~/.config/browser-harness/env.w1
browser-harness <<'PY'
new_tab("https://www.zhihu.com/")
print(page_info())
PY

# 终端 B — 其它站（同时进行）
source ~/.config/browser-harness/env.w2
browser-harness <<'PY'
new_tab("https://duckduckgo.com/")
print(page_info())
PY
```

单个指定实例：

```bash
bh-clone ensure --instance w3 --port 9335
bh-clone sync --instance w3
source ~/.config/browser-harness/env.w3
```

停止：

```bash
bh-clone pool stop w2    # 一个
bh-clone pool stop       # 全部已注册 clone
```

## chrome-devtools MCP

MCP 一般只配 **一个** `browserUrl`（例如 w1 的 9333）。  
真要两路 MCP 需要两套 MCP 配置/宿主，本仓库默认不自动生成。

## 云端多开（官方 harness）

不占本机多份 Chrome 时：

```bash
browser-harness auth login
browser-harness <<'PY'
start_remote_daemon("job-a")
PY
BU_NAME=job-a browser-harness <<'PY'
print(page_info())
PY
```

见官方：https://github.com/browser-use/browser-harness/blob/main/install.md

## 注意

1. **不要**两个进程 `source` 同一个 `env` 还指望互不干扰。  
2. `BU_NAME` 必须不同，否则共用同一个 harness daemon。  
3. Cookie 用 `pool sync` 统一注入；Google 系默认仍不复制。  
4. 主浏览器 HARD_RULES 不变。
