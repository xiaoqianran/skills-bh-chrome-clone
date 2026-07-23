# 强化学习资源检索笔记 + browser-harness / chrome-devtools 对比评估

> 日期：2026-07-23  
> 环境：同一 **clone Chrome `:9333`**（`bh-chrome-clone` cookie-only 同步后的 twin；含知乎 `z_c0`）  
> 顺序：先 **browser-harness**，再 **chrome-devtools MCP**  
> 目标：知乎 + 英文搜索「较新、质量较高」的强化学习（RL）资料，并整理学习路线  

---

## 1. 工具结论（先读这个）

### 1.1 是否同一个浏览器？

**是。** 本机配置下：

| 客户端 | 连接方式 | 目标 |
|--------|----------|------|
| browser-harness | `BU_CDP_URL=http://127.0.0.1:9333` | clone |
| chrome-devtools MCP | `--browserUrl http://127.0.0.1:9333` | **同一个** clone |

二者共享 cookie、标签与登录态。主 Chrome 仅在 `bh-clone sync` 时只读导出 cookie。

### 1.2 速度实测（本轮任务）

| 阶段 | 工具 | 模式 | 墙钟大约 | 知乎结果 | 英文结果 |
|------|------|------|----------|----------|----------|
| A | **browser-harness** | 单进程、**顺序**两标签（知乎→Google） | **~20s**（知乎 ~12s + Google ~7s） | **15 条**高质量专栏/问答 | Google **验证码** 0 条 |
| A+ | harness | 补 **DuckDuckGo** 英文 | **+~11s** | — | **16 条**（Spinning Up / SB3 / CS224R 等） |
| B | **chrome-devtools** | MCP 顺序：导航知乎 → 抽链 → 新开 DDG → 抽链 | **~44s**（含 MCP 往返） | **15 条**（与 harness 高度重合） | **16 条**（与 harness 高度重合） |

说明：

1. **内容质量**：两工具在同一 clone 上打开同一站点，结果几乎一致（同源 DOM）。  
2. **脚本速度**：harness 单次 heredoc 内连续操作更短；devtools 每次 MCP 往返有额外开销。  
3. **并行**：**同一 clone / 同一 CDP daemon 上「真并行」会抢标签与焦点**，官方 harness skill 也提示 local Chrome 不适合多任务并行。  
   - 若要并行搜知乎 + Google：更稳妥是 **两个 cloud browser**（`start_remote_daemon` 不同 `BU_NAME`），或接受顺序双标签。  
   - 本轮 **未做危险的双进程抢同一 clone**；实测为顺序双标签。  
4. **Google**：clone 出口 IP 触发 `google.com/sorry`（机器人验证）。两工具一样挡。改用 **DuckDuckGo** 成功。

### 1.3 能力对比（本任务相关）

| 维度 | browser-harness | chrome-devtools MCP |
|------|-----------------|---------------------|
| 连接 | CLI + daemon + 内嵌 Python | IDE/Agent MCP 工具 |
| 适合 | 批量脚本、CDP、数据抽取、可复现脚本 | 交互式点选、a11y 快照、逐步调试 |
| 多开标签 | `new_tab` 顺序开即可 | `new_page` / `navigate_page` |
| 真并行 | 需多浏览器实例（cloud） | 同左（单 browserUrl） |
| 已登录站 | 依赖 clone cookie（本轮知乎 OK） | 同左 |
| 本轮痛点 | `js()` 需 IIFE 表达式；Google 验证码 | 工具调用链路更长；Google 同样验证码 |

**建议：**

- **检索/爬列表/批量笔记素材** → 优先 **harness**（快、好脚本化）。  
- **需要点按钮、看结构、逐步确认 UI** → **devtools**。  
- **两者不要指望在同一 clone 上无脑并行**；并行请上 cloud 或接受顺序。

---

## 2. 检索条件

- **知乎查询**：`强化学习 最新 教程 综述 2024 2025`  
- **英文查询**：`reinforcement learning best tutorials survey 2024 2025 2026`  
  - Google 失败后改用 DDG：`… spinning up stable baselines`  
- **筛选原则**：偏教程/综述/课程/权威库；优先近年或持续维护；中英文互补。

---

## 3. 知乎侧：较新/高质量线索（harness + devtools 一致）

> 来源：知乎搜索结果页链接抽取（专栏为主）。标题供选题；阅读前请自行核对作者与日期。

| 主题倾向 | 标题 | 链接 |
|----------|------|------|
| 深度 RL 综述（基础→前沿） | 深度强化学习研究综述：从基础理论到前沿进展 | https://zhuanlan.zhihu.com/p/2045130723871417456 |
| LLM + RL 文单 | RL for LLM 高质量文章汇总 | https://zhuanlan.zhihu.com/p/1962321870327093062 |
| Agentic RL 入门 | Agentic RL 入门指南：从 RLVR 到自主智能体的强化学习 | https://zhuanlan.zhihu.com/p/2055761247178584234 |
| 大模型 RL 全解 | 大模型强化学习全解：从PG/PPO基础到LLM与推荐系统实战 | https://zhuanlan.zhihu.com/p/2050604901034620845 |
| 综述整理 | 【强化学习基础】强化学习重要综述整理 | https://zhuanlan.zhihu.com/p/29989400571 |
| 大模型 RL 图解 | 大模型强化学习综述（图解完整版附代码） | https://zhuanlan.zhihu.com/p/1945839286420244395 |
| 演进路线 | 从AlphaGo到Dreamer V3：强化学习的演进路线 | https://zhuanlan.zhihu.com/p/2049504103378706954 |
| 入门大纲 | 强化学习入门（一）学习大纲 | https://zhuanlan.zhihu.com/p/2038965469034590290 |
| 长文概念+实现 | 强化学习：概念、算法、实现（4万字长文） | https://zhuanlan.zhihu.com/p/679215329 |
| 2025 调度应用 | 2025年强化学习求解车间调度文章综述 | https://zhuanlan.zhihu.com/p/2027135376263770749 |
| LLM 全周期 RL 综述 | 复旦、同济和港中文等：强化学习在大语言模型全周期的全面综述 | https://zhuanlan.zhihu.com/p/1956675118332872621 |
| Agentic RL 综述 | 面向LLM Agent强化学习（Agentic RL）综述 | https://zhuanlan.zhihu.com/p/2032098279991808634 |

**知乎阅读建议：**

1. 先入门大纲 / 4 万字长文 → 建立 MDP、价值函数、策略梯度、PPO 图像。  
2. 再读「重要综述整理」+「深度 RL 综述」→ 补算法谱系。  
3. 若目标是 **LLM / Agent**：优先 Agentic RL、RL for LLM 汇总、大模型 RL 全解 / 全周期综述。  
4. 应用向可看 2025 车间调度等垂直综述。

---

## 4. 英文侧：经典 + 较新资源（DDG 实测 + 公开目录）

### 4.1 本轮 DDG 直接命中（两工具一致）

| 资源 | 链接 | 备注 |
|------|------|------|
| **Spinning Up in Deep RL**（OpenAI 教育库） | https://spinningup.openai.com/en/latest/ | 仍是最清晰的算法导读之一 |
| Spinning Up：算法索引 | https://spinningup.openai.com/en/latest/user/algorithms.html | 对照 PPO/DDPG 等 |
| Spinning Up：研究入门 | https://spinningup.openai.com/en/latest/spinningup/spinningup.html | 背景与研究建议 |
| **Stable-Baselines3** 文档 | https://stable-baselines3.readthedocs.io/ | 工业/研究常用实现 |
| SB3 RL 导读页 | https://stable-baselines3.readthedocs.io/en/master/guide/rl.html | |
| SB3 GitHub | https://github.com/DLR-RM/stable-baselines3 | |
| **Stanford CS224R** Spring 2025 课程视频 | 例：Lecture 1 https://www.youtube.com/watch?v=EvHRQhMX7_w | 2025 新课，较新 |
| CS224R Lecture 2 Imitation | https://www.youtube.com/watch?v=WxRDyObrm_M | |
| CS224R Policy Gradients | https://www.youtube.com/watch?v=KCAOXd4IO9o | |
| CS224R Q-Learning | https://www.youtube.com/watch?v=-7kv6jf0isQ | |
| CS224R Frontiers | https://www.youtube.com/watch?v=FacJ_1tTSx4 | |
| Stanford CS234 2024 Lec1 | https://www.youtube.com/watch?v=WsvFL-LjA6U | 经典课 |
| arXiv 示例（检索命中） | https://arxiv.org/abs/2411.18892 | 以文为准核对主题 |

### 4.2 建议补强的权威清单（检索+领域常识，非本页 DOM 唯一来源）

| 资源 | 链接 | 为何值得 |
|------|------|----------|
| Sutton & Barto *RL: An Introduction*（免费书） | http://incompleteideas.net/book/the-book-2nd.html | 理论圣经 |
| Hugging Face Deep RL Course | https://huggingface.co/learn/deep-rl-course/unit0/introduction | 近年维护好、动手友好 |
| David Silver UCL RL Course | https://www.youtube.com/watch?v=2pWv7GOvuf0&list=PLqYmG7hTraZDM-OYHWgPebj2MfCFzFObQ | 经典视频课 |
| Lilian Weng RL 博客系列 | https://lilianweng.github.io/posts/2018-02-19-rl-overview/ | 综述文笔清晰 |
| Meta-RL Tutorial (arXiv, 修订至 2025) | https://arxiv.org/abs/2301.08028 | 较新系统综述 |
| Gymnasium（原 Gym） | https://gymnasium.farama.org/ | 环境标准 |
| CleanRL | https://github.com/vwxyzjn/cleanrl | 单文件清晰实现 |
| RLlib | https://docs.ray.io/en/latest/rllib/index.html | 分布式/工程 |

---

## 5. 一套完整学习笔记（可执行路径）

### 阶段 0：前置（约 3–7 天）

- 概率：期望、条件概率、简单贝叶斯  
- 优化：梯度下降、链式法则  
- Python + PyTorch 或 JAX 基础  

### 阶段 1：经典 RL 基础（约 2–3 周）

1. **Sutton & Barto** 前半：MDP、Bellman、DP、MC、TD、Q-learning。  
2. **David Silver** 课程视频同步。  
3. 小练习：FrozenLake / CartPole 用手写 Q-learning 或 tabular。  

**检查点：** 能默写 Bellman 方程；能说清 on-policy vs off-policy。

### 阶段 2：深度 RL 入门（约 3–4 周）

1. **Spinning Up**：Key Concepts + Algorithms 谱系 + PPO/DDPG 章节。  
2. **Hugging Face Deep RL Course** 按 unit 做完。  
3. **Stable-Baselines3**：用文档跑通 PPO/SAC 在 Gymnasium 环境。  
4. 知乎「入门大纲」「4 万字长文」作中文对照。  

**检查点：** 能解释 policy gradient、advantage、replay buffer；能改一个 SB3 超参并看学习曲线。

### 阶段 3：现代方向（按兴趣选，约 3–6 周）

| 方向 | 优先材料 |
|------|----------|
| **LLM / Reasoning RL** | 知乎：RL for LLM 汇总、大模型 RL 综述、Agentic RL 入门/综述；跟进 RLVR / GRPO / PPO-for-LLM 论文 |
| **Agentic RL** | 知乎 Agentic RL 两篇 + 最新 arXiv；结合 tool-use 环境 |
| **系统/工程** | RLlib、CleanRL、分布式训练笔记 |
| **研究向** | Stanford CS224R 2025 视频 + Meta-RL tutorial + 顶会 oral（如 NeurIPS RLVR 讨论） |

### 阶段 4：项目（巩固）

任选一：

1. 复现 PPO on continuous control（SB3 或 CleanRL）。  
2. 做一个 **LLM + 可验证奖励** 的小实验（数学题/代码题）。  
3. 读 1 篇 2024–2025 综述并写 2 页笔记（问题设定、方法谱系、开放问题）。  

---

## 6. 推荐「最小书单」（新环境可收藏）

**必读 5：**

1. Sutton & Barto 书  
2. Spinning Up 文档  
3. Hugging Face Deep RL Course  
4. Stable-Baselines3 文档  
5. 知乎：Agentic RL 入门 **或** 大模型 RL 综述（视目标二选一优先）

**选修：**

- CS224R 2025 全套  
- Meta-RL Tutorial (arXiv:2301.08028)  
- Lilian Weng RL posts  
- 知乎：深度 RL 综述 + RL for LLM 汇总  

---

## 7. 工具使用备忘（本仓库）

```bash
# 起 clone（不动主浏览器）
bh-clone ensure   # 或 bh-clone up
source ~/.config/browser-harness/env

# harness 脚本检索
browser-harness <<'PY'
ensure_real_tab()
new_tab("https://www.zhihu.com/search?type=content&q=强化学习")
wait_for_load()
print(page_info())
# js 必须是可求值表达式 / IIFE，不要传未调用的 () => {}
PY

# 登录过期
# 主 Chrome Allow remote debugging 后：
bh-clone sync
```

**Google 验证码：** clone 数据中心 IP 常见；换 DDG/Bing，或主浏览器人工搜后把链接贴给 Agent。

**并行：**  

- ❌ 不推荐两个 harness 进程抢同一个 `:9333`  
- ✅ 顺序 `new_tab` 足够快（本轮知乎+英文 ~30s 量级含 DDG）  
- ✅ 真并行 → Browser Use cloud 多实例  

---

## 8. 原始抽取数据位置

- harness 结构化结果：`/tmp/harness-rl-search.json`（本机会话临时）  
- 本文为整理后的可存档笔记（本文件）  

---

## 9. 一句话总结

| 问题 | 答案 |
|------|------|
| harness 和 devtools 是否同一浏览器？ | **是，都是 clone :9333** |
| 谁更快？ | **harness 脚本墙钟更短**；devtools 适合交互 |
| 能否同时搜知乎+Google？ | **顺序双标签可以**；真并行需多浏览器实例；本轮 Google 被验证码，改 DDG |
| 资料够用吗？ | 知乎 2024–2025 向专栏丰富；英文以 Spinning Up + SB3 + CS224R 2025 + HF Course 为主干 |

---

*生成说明：检索在 clone 上完成，未杀主 Chrome；Google 被挡后使用 DuckDuckGo 与公开目录补全英文清单。*
