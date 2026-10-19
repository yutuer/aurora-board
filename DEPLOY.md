# 部署指南（GitHub Pages）

本文档面向首次部署。已部署过、只想更新内容的话，直接跳到 [日常更新](#日常更新)。

## 前置条件

- GitHub 账号（本机 git 已配置 `user.name = yutuer`、`user.email = yutuerzf@163.com`）
- 已安装 Git（2.55.0 ✓）
- 仓库已包含 `index.html`（单文件应用本体）与 `.github/workflows/deploy.yml`（部署工作流）

## 一、创建 GitHub 仓库

在 <https://github.com/new> 新建仓库，建议：

| 选项 | 建议值 | 原因 |
|---|---|---|
| Repository name | `aurora-board` | 或任意名字 |
| Visibility | **Public** | 私有仓库需 GitHub Pro 才能开 Pages |
| Initialize this repository | **不勾选** | 本地已有 git 历史，避免冲突 |

## 二、推送代码

在项目目录执行：

```bash
cd C:/Users/yutue/WorkBuddy/trello看板
git remote add origin https://github.com/yutuer/aurora-board.git
git branch -M main
git push -u origin main
```

推送时浏览器会弹出授权窗口，登录并授权即可。

> 若提示 `could not read Username`，说明凭据未配置。改用 Personal Access Token：
> ```bash
> git remote set-url origin https://<你的TOKEN>@github.com/yutuer/aurora-board.git
> ```

## 三、开启 GitHub Pages

1. 进入仓库 **Settings → Pages**
2. **Build and deployment → Source** 选 **GitHub Actions**
3. 保存

第 2 步的推送已自动触发一次部署，通常在 **1–2 分钟**内完成。

## 四、确认部署成功

访问：

```
https://yutuer.github.io/aurora-board/
```

页面上会显示一个版本戳（如 `c0678a7 - 10-19 17:42 UTC`）。
**只要戳不是 `dev`，就说明部署成功且是最新版。**

也可在仓库 **Actions** 页查看 `Deploy to GitHub Pages` 工作流是否全绿。

---

## 日常更新

改完代码后只需两步：

```bash
git add -A
git commit -m "描述你的改动"
git push
```

push 会自动触发部署，无需手动做任何配置。

### ⚠️ 重要：GitHub Pages 有 10 分钟缓存

若 push 后线上没变化：

1. **先看构建戳**——戳变了说明部署成功，只是浏览器缓存
2. **强制刷新**：`Ctrl + F5`（或 `Ctrl + Shift + R`）
3. 等 10 分钟后 CDN 自动更新

响应头 `Cache-Control: max-age=600`，浏览器在此期间**根本不会向服务器发请求**，普通 F5 无效。

---

## 常见问题

**Q: 线上显示 404？**
仓库没有 `index.html`，或 Pages 来源没设为 GitHub Actions。本项目已含 `index.html`，只需检查第 3 步。

**Q: 提交后 CI 报「构建戳注入失败」？**
`index.html` 里的 `id="build-stamp">dev<` 锚点被改动了。恢复该锚点即可。

**Q: 能用自定义域名吗？**
可以。在 **Settings → Pages → Custom domain** 填入域名，然后在域名服务商处添加 CNAME 记录指向 `yutuer.github.io`。注意：**先配 DNS 再开 Pages 自定义域名**，否则可能触发证书校验失败。

**Q: 数据会丢吗？**
数据存在浏览器 localStorage（键 `aurora.board.v1`），**不上传服务器**。换浏览器、换设备、清缓存都会丢。用页面右上角的「导出 JSON」备份。

---

## 文件清单

| 文件 | 作用 |
|---|---|
| `index.html` | 应用本体（单文件，含全部 HTML/CSS/JS） |
| `.github/workflows/deploy.yml` | 部署工作流：注入构建戳 → 上传 → 发布 |
| `.nojekyll` | 禁用 Jekyll 处理，确保文件原样发布 |
| `.gitignore` | 排除 `.workbuddy/` 等本地目录 |
| `.gitattributes` | 统一 LF 换行，避免跨平台 diff 噪声 |
| `README.md` | 项目说明 |
| `LICENSE` | MIT 许可 |
