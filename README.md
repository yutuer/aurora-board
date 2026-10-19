# Aurora Board · 单文件 Trello 看板

高颜值看板，纯原生 HTML / CSS / JavaScript 实现，**零第三方库**。

![tech](https://img.shields.io/badge/HTML-single--file-ff6a3d) ![deps](https://img.shields.io/badge/dependencies-0-3ecf8e)

## 特性

| 能力 | 说明 |
|---|---|
| 卡片跨列拖动 | 支持拖到任意列的任意位置，列内实时排序 |
| 列表横向拖拽 | 按住列标题栏整体拖动，改变列序 |
| 平滑让位动画 | FLIP 技术，周边卡片位移过渡而非闪现 |
| 边缘自动滚动 | 拖到边缘自动横向/纵向滚动，速度随距离递增 |
| 原位放大弹窗 | 点击卡片从其原位置缩放展开为详情页 |
| 子任务清单 | 增删改、勾选完成、进度条实时联动 |
| 多颜色标签 | 9 种标签色，可增可删，卡片与弹窗双向同步 |
| 搜索 / 筛选 | 标题描述全文搜索 + 标签筛选 |
| 暗色 / 亮色主题 | 一键切换，选择本地持久化 |
| 数据持久化 | localStorage 自动保存，支持 JSON 导入导出 |

## 使用

直接双击 `index.html` 即可在浏览器打开，无需服务器。

数据保存在浏览器 localStorage（键名 `aurora.board.v1`），更换浏览器或清除缓存会丢失，可用「导出 JSON」备份。

## 技术说明

- **拖拽**：原生 Pointer Events 手写，未使用 HTML5 Drag & Drop（后者无法控制跟随精度与动画）
- **让位动画**：FLIP（First-Last-Invert-Play），280ms `cubic-bezier(.22,1,.36,1)`
- **弹窗展开**：由卡片 `getBoundingClientRect()` 反算起始 `translate + scale` 帧，实现无缝衔接
- **无障碍**：支持 `prefers-reduced-motion`，降级动画至 0.08s

## 浏览器支持

现代浏览器（Chrome / Edge / Safari / Firefox 近两年版本）。依赖 Pointer Events 与 CSS 自定义属性。

## License

MIT
