# Cookie-only model

> 默认工作方式。与 [HARD_RULES.md](HARD_RULES.md) 一起读。

## 目标

**只复制 cookie。** 主浏览器坚决不受影响。

```text
MAIN (daily Chrome)          CLONE (automation)
─────────────────            ──────────────────
process: user only           process: bh-clone ensure / kill_clone
disk:    READ at most        disk:    WRITE ok
CDP:     getAllCookies only  CDP:     setCookies (+ filter purge)
```

```text
MAIN ──read──► JSON (0600) ──write──► CLONE :9333
         ▲
    user Allow (if needed)
```

没有第四步「修一下主浏览器」。

## 默认命令

| 命令 | 行为 |
|------|------|
| `bh-clone sync` | cookie-only：导出 → 注入；无全量 profile rsync |
| `bh-clone init` | 同上（首次建空 clone 目录） |
| `bh-clone ensure` / `up` | **只**启停 clone |
| `bh-clone sync --with-profile` | **可选**：main→clone rsync（仍不杀 MAIN） |

## 四条不变量

1. **进程**：Agent 不得 kill 主 Chrome；kill 只匹配 clone `user-data-dir`。  
2. **磁盘**：不得写主 profile（Singleton / Local State / Cookies…）。  
3. **CDP 方向**：MAIN 只读；写 cookie 必须 `BU_CDP_URL=http://127.0.0.1:9333`。  
4. **失败可停**：MAIN 导出失败 → 打印说明并 exit；**禁止**杀主浏览器作 fallback。

## 导出失败时（标准行为）

CLI 调用 `die_main_cookie_export_failed`：

1. 说明 cookie-only 模型  
2. 请用户在主 Chrome 打开 `chrome://inspect/#remote-debugging` 并 Allow  
3. 明确列出 **永不会做** 的事（杀进程、改 Local State、主 profile RDP 重启）  
4. exit 1  

用户完成后重新 `bh-clone sync`。

## 非目标

- 把 bilibili / grok 是否登录当作安装成功条件  
- 为「导出质量」去动 MAIN 生命周期  
- chrome-devtools `--auto-connect` 主浏览器  

## 相关

- [HARD_RULES.md](HARD_RULES.md)  
- [design.md](design.md)  
- `cli/scripts/sync.sh` / `cli/lib/common.sh`  
