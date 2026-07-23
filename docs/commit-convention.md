# Commit 规范（阿里风格 / Conventional Commits）

格式：

```text
<type>(<scope>): <subject>

<body>

<footer>
```

## type

| type | 含义 |
|------|------|
| feat | 新功能 |
| fix | 缺陷修复 |
| docs | 文档 |
| style | 格式（不影响逻辑） |
| refactor | 重构 |
| perf | 性能 |
| test | 测试 |
| chore | 杂项构建/工具 |
| build | 构建系统 |
| ci | CI |
| revert | 回滚 |

## 示例

```text
feat(sync): 支持 --with-profile 全量 rsync
fix(cli): 解析 ~/.local/bin 符号链接到仓库根
docs: 补充 bilibili 登录探测说明
```

subject 使用祈使句/简洁中文或英文均可；本仓库默认中文 subject。
