# Aurora Board · 单文件 Trello 看板

> **本文件是项目台账**：记录当前状态、已完成成果、踩坑经验、后续待办。
> 接手或推进本项目时，**先读这里**，再读代码。

高颜值看板，纯原生 HTML / CSS / JavaScript 实现，**零第三方库**。

![tech](https://img.shields.io/badge/HTML-single--file-ff6a3d) ![deps](https://img.shields.io/badge/dependencies-0-3ecf8e) ![status](https://img.shields.io/badge/status-online-3ecf8e)

| 项目 | 值 |
|---|---|
| 线上地址 | https://yutuer.github.io/aurora-board/ |
| 仓库 | https://github.com/yutuer/aurora-board |
| 本地路径 | `C:\Users\yutue\WorkBuddy\trello看板` |
| 应用本体 | `index.html`（单文件，约 75 KB） |
| 数据存储 | 浏览器 localStorage，键 `aurora.board.v1`，**不上传服务器** |
| 当前状态 | ✅ 已上线（构建戳 `dcdeb85`） |

---

## 一、当前进度

### ✅ 已完成

| 阶段 | 内容 | 提交 |
|---|---|---|
| P1 功能实现 | 单文件看板全部能力 | `dedfc25` |
| P2 自动化部署 | GitHub Actions 工作流 + 构建戳 | `c0678a7` |
| P3 文档 | 部署指南 | `dcdeb85` |
| P4 上线验证 | 根路径 200、构建戳注入、与本地逐字节一致 | — |
| P5 依赖升级 | Actions 升至最新版，消除 Node 20 弃用警告 | `3c61b83` |
| P6 校验修正 | 构建戳校验判据改为「实际戳==期望戳」，堵住锚点改名时的静默失效 | `2d298df` |

**验证结论**（2026-10-19 17:45）：
- `has_pages: true`，`https://yutuer.github.io/aurora-board/` 返回 **200**
- 线上构建戳 `dcdeb85 - 10-19 09:45 UTC`（CI 注入成功）
- 线上内容与本地提交版**归一化后逐字节一致**（各 73,486 字符，差异仅为构建戳）

### 📋 后续待办（尚未实现）

| 优先级 | 事项 | 说明 |
|---|---|---|
| P1 | 列宽拖拽调整 | 当前列宽固定 308px |
| P2 | 多看板切换 | 目前单看板，数据键写死 `aurora.board.v1` |
| P2 | 卡片附件/图片 | 目前仅文本 |
| P3 | 截止日期提醒 | 只展示，不提醒 |
| P3 | 键盘快捷键 | 仅 Esc 关闭弹窗 |

---

## 二、功能清单

| 能力 | 说明 | 实现要点 |
|---|---|---|
| 卡片跨列拖动 | 拖到任意列的任意位置，列内实时排序 | Pointer Events + FLIP |
| 列表横向拖拽 | 按住列标题栏整体拖动，改变列序 | 按横向命中位置判定落点 |
| **平滑让位动画** | 周边卡片位移过渡，**不闪现** | FLIP，280ms `cubic-bezier(.22,1,.36,1)` |
| **边缘自动滚动** | 拖到边缘自动横向/纵向滚动 | rAF 循环，速度随距边距离递增 |
| **原位放大弹窗** | 从卡片原位置缩放展开 | rect 反算 `translate+scale` 起始帧 |
| 子任务清单 | 增删改、勾选、进度条实时联动 | 双击改名，删除有淡出动画 |
| 多颜色标签 | 9 色，可增可删 | 卡片与弹窗双向同步 |
| 搜索 / 筛选 | 全文搜索 + 标签筛选（可多选） | 标题/描述/子任务/评论全文 |
| 暗色 / 亮色主题 | 一键切换 | 选择持久化到 `aurora.pref.v1` |
| 数据持久化 | localStorage 自动保存 | 支持 JSON 导入导出 |
| 统计栏 | 列数 / 卡片数 / 子任务完成数 | 实时联动 |
| 删除确认 | 列表与卡片删除均二次确认 | 独立 confirm 弹窗 |

### 标签色板（9 色）

`green 设计` · `yellow 待评审` · `orange 紧急` · `red 阻塞` · `blue 研发` · `purple 调研` · `teal 已完成` · `pink 营销` · `slate 杂项`

---

## 三、技术决策与理由

| 决策 | 理由 |
|---|---|
| **手写 Pointer Events，不用 HTML5 Drag & Drop** | DnD 无法控制幽灵跟随精度、不支持自定义动画、触屏行为不可控 |
| **FLIP 实现让位动画** | 先测旧位置 → 改 DOM → 反向 `translate` → reflow → 过渡归零。这是"平滑滑开"而非"闪现"的唯一可靠做法 |
| **弹窗用 rect 反算起始帧** | 记录卡片 `getBoundingClientRect()`，反推 `translate + scale(sx,sy)`，`transform-origin: 0 0`，实现从卡片"长出来"的无缝感 |
| **列 `max-height` + `align-self:flex-start`** | 内容少不留白，超出则列内滚动。这样列内自动滚动才是真能力，而不是被撑高的假象 |
| **官方 Actions，不用第三方 action** | 第三方 Pages action 有供应链风险；官方四步（checkout/configure/upload/deploy）已足够 |
| **构建戳注入 + 失败校验** | 线上直接显示版本号，一眼分辨"没部署"和"浏览器缓存"；锚点变更时 CI 直接失败，不静默产出 `dev` 戳 |

---

## 四、踩坑记录（重要，避免重犯）

### 🐛 实现阶段修复的 4 个真实 bug

| # | Bug | 症状 | 根因 | 修法 |
|---|---|---|---|---|
| 1 | **跨列拖动后数据丢失** | DOM 有 4 张卡，localStorage 只有 3 张，刷新后卡片消失 | `syncFromDom` 用 `l.cards.find()` 只在目标列原有卡片里找，跨列拖入的卡片被 `filter(Boolean)` 丢弃 | 先建全局 `id→card` 映射再回填 |
| 2 | **列表拖拽完全失效** | 每帧抛 `ReferenceError: d is not defined`，24 条控制台错误 | 清理 `activate()` 时误留 `const sb=d.node...` | 改为 `drag.node` |
| 3 | **列表换位错乱** | 拖拽后列序错乱、"添加列表"按钮跑到中间 | `target.nextElementSibling` 可能返回 `.add-list` 按钮 | 判定只遍历 `.list`，加 ±6px 容差 |
| 4 | **拖完误开弹窗** | 拖拽松手瞬间弹出详情窗 | `pointerup` 后紧跟的 `click` 命中卡片 | 加 `suppressClick` 标志 + 60ms 延时清除 |

### 🐛 布局与体验修正

| 问题 | 修法 |
|---|---|
| 列内容少时底部大片留白 | `.board-inner{height:100%}` + 列 `align-self:flex-start` |
| 弹窗描述框强制抢焦，橙色边框过于抢眼 | 移除自动 `focus()` |
| 子任务为空时进度条与提示重复 | 无子任务时隐藏进度条与百分比 |
| 窄屏描述框留白过大 | `min-height` 96px → 72px |

### ⚠️ 部署阶段的坑

| 坑 | 真相 |
|---|---|
| **Pages 缓存** | GitHub Pages 走 Fastly CDN，`Cache-Control: max-age=600`。10 分钟内浏览器**压根不发请求**，普通 F5 无效，须 `Ctrl+F5` |
| **CI 失败 ≠ 代码有问题** | 本项目首次部署失败于 `Setup Pages`，因 `has_pages: false`（Pages 未启用）。**必须做步骤级定位**，别一看到红叉就改代码 |
| **根路径 404** | 仓库必须含 `index.html`，`path: .` 全量上传也救不了 |
| **构建戳注入** | 依赖 `id="build-stamp">dev<` 精确锚点。校验判据是「**实际戳 == 期望戳**」而非「dev 是否还在」——后者在锚点被改名时会误判通过（`sed` 注到新名字，旧串自然找不到）。锚点被改名或删除时 CI 直接失败，不会静默产出 `dev` 戳 |
| **Node 20 弃用警告** | Actions 已被强制跑在 Node 24 上（旧版本 action 触发警告）。已升级为最新：`checkout@v7`、`configure-pages@v6`、`upload-pages-artifact@v5`、`deploy-pages@v5` |

### 📌 方法论教训

1. **验证不能只看工具返回值** —— 判断"线上是新版本"要抓真实内容逐字节比对，不是看 HTTP 200。
2. **公开仓库的 GitHub API 免鉴权** —— 判断"部署跑没跑、卡哪步"最快的手段：
   ```bash
   curl -s "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=1"
   curl -s "https://api.github.com/repos/<owner>/<repo>/actions/runs/<id>/jobs"   # 步骤级
   curl -s "https://api.github.com/repos/<owner>/<repo>" | grep has_pages
   ```
3. **测完必须收尾** —— 后台服务不留残留。判定标准是"端口真的空了"，不是"工具返回成功"。
4. **校验逻辑本身要被校验** —— 构建戳的守卫最初写成「查 `dev` 还在不在」，看起来合理，但锚点一旦被改名，`sed` 会注到新名字上、旧串自然找不到 → **守卫误判为通过，静默失效**。做反向演练（故意破坏输入，确认守卫真会拦住）才发现。**判据要落在"结果等于期望值"，不是"坏值是否消失"**。

---

## 五、开发与部署

### 日常更新

```bash
cd C:/Users/yutue/WorkBuddy/trello看板
git add -A
git commit -m "描述你的改动"
git push          # 自动触发 CI 部署
```

### 验收流程（每次改动后）

1. 本地起服务测：`python -m http.server 8791`，浏览器打开 `http://127.0.0.1:8791/`
2. **测完立即收尾**：`TaskStop(task_id)` + `Get-NetTCPConnection -LocalPort 8791 -State Listen` 确认端口已空
3. 推送后查部署：`curl -s "https://api.github.com/repos/yutuer/aurora-board/actions/runs?per_page=1"`
4. 验证线上：抓页面看构建戳是否更新 + 内容是否与本地一致

> ⚠️ 本环境 `curl` 返回 502 是代理兜底响应，**不能作为服务存活判据**，必须用 `Get-NetTCPConnection` 查真实监听。

### 首次部署（如需重建）

详见 [`DEPLOY.md`](DEPLOY.md)。

---

## 六、文件结构

```
aurora-board/
├── index.html                    # 应用本体（HTML+CSS+JS 全在此）
├── .github/workflows/deploy.yml  # CI：注入构建戳 → 上传 → 发布
├── .nojekyll                     # 禁用 Jekyll 处理
├── .gitignore                    # 排除 .workbuddy/ 等本地目录
├── .gitattributes                # 统一 LF 换行
├── README.md                     # 本文件（项目台账）
├── DEPLOY.md                     # 部署指南
└── LICENSE                       # MIT
```

---

## 七、浏览器支持

现代浏览器（Chrome / Edge / Safari / Firefox 近两年版本）。依赖 Pointer Events 与 CSS 自定义属性。

无障碍：`prefers-reduced-motion` 下动画降级至 0.08s。

## License

MIT
