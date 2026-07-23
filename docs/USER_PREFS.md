# 用户偏好（Agent 请遵守）

## 标签页

- 不需要的标签页 → **渐进式关闭**（`Target.closeTarget` / chrome-devtools `close_page`）。
- 内存相对够用 → 可以双开/多开 clone 做并行；用完仍应顺手关页。
- 至少保留 1 个标签，避免无页可挂。
- **禁止**为省内存杀主 Chrome；只清理 clone 上的 page。

## 相关

- 多开：`docs/MULTI_INSTANCE.md`、`bh-clone pool`
- 主浏览器红线：`docs/HARD_RULES.md`
