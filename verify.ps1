# 台账自检：把 README.md 里的每条声明与 index.html / git 实际值逐条比对
# 用法：powershell -ExecutionPolicy Bypass -File verify.ps1
# 注意：本文件必须存为 UTF-8 **带 BOM**，否则 PowerShell 5.1 按 ANSI 解码会解析失败
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$html = [System.IO.File]::ReadAllText("$root/index.html", [System.Text.Encoding]::UTF8)
$readme = [System.IO.File]::ReadAllText("$root/README.md", [System.Text.Encoding]::UTF8)
$pass = 0; $fail = 0; $skip = 0
function Check($name, $ok, $detail) {
  if ($ok) { $script:pass++; Write-Host ("  [OK]   {0}" -f $name) -ForegroundColor Green }
  else { $script:fail++; Write-Host ("  [FAIL] {0}  <-- {1}" -f $name, $detail) -ForegroundColor Red }
}
function Skip($name, $detail) {
  $script:skip++; Write-Host ("  [SKIP] {0}  ({1})" -f $name, $detail) -ForegroundColor DarkGray
}
function GetNum($pattern, $text) {
  $m = [regex]::Match($text, $pattern)
  if ($m.Success) { return [double]$m.Groups[1].Value } else { return -1 }
}

Write-Host "`n=== 1. 语法与完整性 ===" -ForegroundColor Cyan
$tmp = Join-Path $env:TEMP 'aurora_verify.js'
$m = [regex]::Match($html, '(?s)<script>(.*?)</script>')
[System.IO.File]::WriteAllText($tmp, $m.Groups[1].Value, (New-Object System.Text.UTF8Encoding($false)))
node --check $tmp 2>&1 | Out-Null
Check "JS 语法通过 (node --check)" ($LASTEXITCODE -eq 0) "node --check 退出码 $LASTEXITCODE"
$anchor = [regex]::Match($html, 'id="build-stamp">([^<]*)<')
Check "CI 锚点存在且为 dev" ($anchor.Success -and $anchor.Groups[1].Value -eq 'dev') "实际: [$($anchor.Groups[1].Value)]"
$ext = [regex]::Matches($html, '(?i)(src|href)\s*=\s*"(https?:)?//[^"]*"')
Check "零外部资源" ($ext.Count -eq 0) "发现 $($ext.Count) 个外链"
Check "无写死色板残留 (LABEL_COLORS/LABEL_NAMES)" (($html -notmatch 'LABEL_COLORS') -and ($html -notmatch 'LABEL_NAMES')) "仍有残留"
Check "未使用 :has() 选择器" ($html -notmatch ':has\(') "用到了 :has()，浏览器支持需重新评估"
Check "未使用 aspect-ratio" ($html -notmatch 'aspect-ratio') "用到了 aspect-ratio，浏览器支持需重新评估"
# 「纯本地存储、刻意不引入后端」是主人的明确决定（台账 技术决策表）——把它变成可执行断言
$net = [regex]::Matches($html, '(?i)\b(fetch\s*\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|navigator\.sendMail)\b')
Check "零网络请求（守住「不引入后端」的决定）" ($net.Count -eq 0) ("发现 $($net.Count) 处网络调用: " + (($net | ForEach-Object { $_.Value }) -join ', '))
$ls = ([regex]::Matches($html, 'localStorage\.(set|get)Item')).Count
Check "localStorage 读写调用存在 ($ls 处)" ($ls -ge 4) "存储调用异常少，可能数据流断了"

Write-Host "`n=== 2. README 数字声明 vs 代码实际 ===" -ForegroundColor Cyan
$bytes = (Get-Item "$root/index.html").Length
$kb = [math]::Round($bytes / 1024, 1)
$claimed = GetNum '单文件，约\s*([\d.]+)\s*KB' $readme
# 体积按区间校验（±15%），避免每改一行就要改台账；但区间写错仍会被拦下
Check "应用体积在声明区间内 (README 约 $claimed KB / 实际 $kb KB)" ($kb -ge ($claimed * 0.85) -and $kb -le ($claimed * 1.15)) "实际 $kb KB，超出 ±15% 区间"
$lines = ($html -split "`n").Count
Check "index.html 行数 = $lines" ($lines -gt 1500) "异常"
$pal = [regex]::Match($html, "(?s)const TAG_PALETTE=\[(.*?)\];")
$palCount = ([regex]::Matches($pal.Groups[1].Value, '#[0-9a-fA-F]{6}')).Count
Check "预设色板 20 色 (README 写 20)" ($palCount -eq 20) "实际 $palCount"
$thr = GetNum '/1000\s*>\s*(\d+);' $html
$readmeThr = GetNum '亮度\s*>\s*(\d+)\s*时' $readme
Check "浅色阈值一致 (README $readmeThr / 代码 $thr)" ($thr -eq $readmeThr -and $thr -gt 0) "代码 $thr / README $readmeThr"
$so = GetNum 'const DUE_SOON_DAYS=(\d+);' $html
Check "临期窗口 = ${so} 天" ($so -eq 3) "实际 $so"
$lw = GetNum '--list-w:(\d+)px' $html
Check "列宽 $lw px (待办项所述)" ($lw -eq 308) "实际 $lw"

Write-Host "`n=== 3. 标签体系 ===" -ForegroundColor Cyan
Check "标签表键 = aurora.labels.v1" ($html -match "LABELS_STORE='aurora\.labels\.v1'") "未找到"
Check "看板键 = aurora.board.v1" ($html -match "STORE='aurora\.board\.v1'") "未找到"
Check "主题键 = aurora.pref.v1" ($html -match "PREF='aurora\.pref\.v1'") "未找到"
$bi = [regex]::Match($html, '(?s)const BUILTIN_LABELS=\[(.*?)\];')
$biCount = ([regex]::Matches($bi.Groups[1].Value, "id:'")).Count
Check "内置标签 9 个 (README 写 9)" ($biCount -eq 9) "实际 $biCount"
$ids = [regex]::Matches($bi.Groups[1].Value, "id:'(\w+)'") | ForEach-Object { $_.Groups[1].Value }
Check "内置 id 与 README 声明一致" (($ids -join ',') -eq 'green,yellow,orange,red,blue,purple,teal,pink,slate') ($ids -join ',')
$readmeNames = ([regex]::Matches($readme, '`(设计|待评审|紧急|阻塞|研发|调研|已完成|营销|杂项)`')).Count
Check "README 列出的内置标签名 >= 9" ($readmeNames -ge 9) "只找到 $readmeNames 个"
Check "标签表独立存储函数存在" (($html -match 'function saveLabels') -and ($html -match 'function pruneDanglingLabels')) "缺失"
Check "导入导出带标签表" (($html -match 'labels:labels') -and ($html -match 'd\.labels')) "缺失"

Write-Host "`n=== 4. 台账中的提交号必须真实存在 ===" -ForegroundColor Cyan
$hashes = [regex]::Matches($readme, '`([0-9a-f]{7})`') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($hx in $hashes) {
  $t = (git -C $root cat-file -t $hx 2>&1 | Out-String).Trim()
  Check "提交 $hx 存在" ($t -eq 'commit') "git 报: $t"
}
# 台账必须指向"最后一次改动应用代码的提交"。
# 不检查 HEAD 本身：docs-only 提交无法在自身内容里预知自己的哈希（先有鸡还是先有蛋），
# 这条检查逻辑上永不可满足，只会制造假告警。
$codeHead = (git -C $root log -1 --format=%h -- index.html).Trim()
Check "台账记录了最后一次代码提交 ($codeHead)" ($readme -match [regex]::Escape($codeHead)) "该提交未出现在 README"

Write-Host "`n=== 5. 仓库文件与台账文件结构一致 ===" -ForegroundColor Cyan
$tracked = @(git -C $root ls-files)
Check "跟踪文件 9 个 (实际 $($tracked.Count))" ($tracked.Count -eq 9) "实际 $($tracked.Count)"
foreach ($f in $tracked) {
  $base = Split-Path -Leaf $f
  if ($f -eq '.github/workflows/deploy.yml') { $base = 'deploy.yml' }
  Check "台账提及 $base" ($readme -match [regex]::Escape($base)) "未提及"
}
$dirty = (git -C $root status --porcelain | Out-String).Trim()
Check "工作区干净" ([string]::IsNullOrWhiteSpace($dirty)) "有未提交改动: $dirty"

Write-Host "`n=== 6. 功能入口存在性 ===" -ForegroundColor Cyan
foreach ($kv in @(
  @("id=`"tagMgrBtn`"", '标签管理入口按钮'),
  @("id=`"remindBtn`"", '截止日期提醒铃铛'),
  @("id=`"remindPanel`"", '提醒中心面板'),
  @("id=`"labelForm`"", '标签选择器内新建表单'),
  @("'card-fx'", '卡片覆盖层 .card-fx'),
  @("'due-chip'", '到期 chip .due-chip'),
  @("classList.add('flash')", '跳转闪烁'),
  @("id=`"build-stamp`"", '构建戳锚点')
)) {
  Check "$($kv[1]) 存在" ($html -match [regex]::Escape($kv[0])) "未找到 $($kv[0])"
}
# 长列表必须能滚动：卡片不能在纵向 flex 容器里被压扁（.card 带 overflow:hidden，
# 自动最小尺寸会归零，flex-shrink 默认值就能把它压成任意扁，滚动条永不出现）
Check "卡片不参与伸缩 .list-body > .card{flex:none}" ($html -match '\.list-body\s*>\s*\.card\s*\{\s*flex\s*:\s*none') "缺少该规则，长列表会塌陷且没有滚动条"
Check "列内内容区可滚动 .list-body{...overflow-y:auto}" ($html -match '\.list-body\{[^}]*overflow-y\s*:\s*auto') "缺少 overflow-y:auto"

Write-Host "`n=== 6b. Agent 工单流三件套 ===" -ForegroundColor Cyan
# 状态字段：固定枚举（不是普通标签）
Check "状态枚举定义 (todo/doing/review/done)" ($html -match "todo\s*:\s*\{name:'待处理'" -and $html -match "review\s*:\s*\{name:'待复查'") "状态枚举缺失"
Check "状态筛选栏 (#statusChips)" ($html -match 'id="statusChips"') "缺少状态筛选栏（复查工作台入口）"
Check "状态写入卡片数据 (card.status)" ($html -match 'card\.status\s*=') "状态未写回数据"
# 富文本渲染器：自写 + 白名单
Check "Markdown 子集渲染器 (mdToHtml)" ($html -match 'function mdToHtml') "缺少渲染器"
Check "渲染前先 HTML 转义 (escHtml)" ($html -match 'function escHtml') "缺少转义，XSS 风险"
Check "URL 白名单（只放行 http/https/mailto）" ($html -match "safeLinkUrl" -and $html -match "safeImgUrl") "缺少 URL 白名单"
Check "仅允许 img: / http(s) 图片地址" ($html -match '\^img:\[A-Za-z0-9_-\]\+\$') "图片地址未做白名单"
# 图片存储：IndexedDB
Check "图片存 IndexedDB" ($html -match "indexedDB\.open" -and $html -match "aurora-media") "缺少 IndexedDB 图片存储"
Check "图片引用格式 ![..](img:ID)" ($html -match 'img:' -and $html -match 'collectImageIds') "缺少图片引用机制"
# 文件桥
Check "文件同步入口 (#syncBtn)" ($html -match 'id="syncBtn"') "缺少文件同步按钮"
Check "File System Access API 接入" ($html -match 'showSaveFilePicker' -and $html -match 'showOpenFilePicker') "缺少文件选择能力"
Check "按 rev 判定谁覆盖谁（逐项目）" ($html -match 'rev<=p\.rev') "缺少 rev 冲突判定"
Check "文件内容含 labels/images/status" ($html -match 'labels:labels' -and $html -match 'images:imgs') "导出 payload 不完整"

Write-Host "`n=== 6c. 多项目工单流 ===" -ForegroundColor Cyan
Check "多项目数据模型 projects[]" ($html -match 'let projects=\[\]' -and $html -match 'let curKey=') "缺少多项目模型"
Check "聚合视图按状态分列" ($html -match 'function buildAggregate' -and $html -match "STATUS_KEYS\.map") "聚合视图未按状态分列"
Check "项目切换器 (#projSwitch)" ($html -match 'id="projSwitch"' -and $html -match 'function renderProjSwitch') "缺少项目切换器"
Check "工单根目录扫描" ($html -match 'showDirectoryPicker' -and $html -match 'function scanProjects') "缺少目录扫描"
Check "写入按项目路由" ($html -match 'async function writeFile\(p\)' -and $html -match 'scheduleFileWrite\(p\)') "写入未按项目路由"
Check "逐项目读取比对 rev" ($html -match 'async function readProjects' -and $html -match 'rev<=p\.rev') "读取未按项目比对 rev"
Check "上一版回滚备份" ($html -match 'function backupProject' -and $html -match 'function restoreBackup') "缺少备份/回滚"
Check "聚合视图只读保护" ($html -match '只读汇总视图') "聚合视图未做只读保护"
Check "聚合视图点卡片自动切项目" ($html -match "card\.dataset\.proj" -and $html -match 'switchTo\(pj\)') "汇总视图点卡片未跳转到所属项目"
Check "汇总视图不渲染状态 chip" ($html -match "st!=='todo'&&!card\.__proj") "汇总视图重复显示状态 chip"
Check "一键新建工单项目（根目录建子目录 + 写初始 board.json + 项目目录写指针）" ($html -match 'function createProjectDir' -and $html -match "getDirectoryHandle\(projName,\{create:true\}\)" -and $html -match "getFileHandle\('board\.json',\{create:true\}\)" -and $html -match 'function writeBoardPath') "缺少新建工单项目入口"
# 取件脚本：必须自带 UTF-8 BOM，否则 PowerShell 5.1 会按 ANSI 解码 → 中文乱码 → 解析失败
Check "take.ps1 自带 UTF-8 BOM（PS 5.1 硬要求）" ($html -match "TAKE_PS1=\[\s*'\\uFEFF") "take.ps1 首行缺 U+FEFF，PS 5.1 下会乱码解析失败"
Check "取件脚本会标记 doing 防重复领取" ($html -match '\$c\.status\s*=\s*"doing"') "取件未标记 doing，会重复领取同一张卡"
Check "项目目录写 .board-path 指针" ($html -match "getFileHandle\('\.board-path'") "缺少 .board-path 指针"
Check "目录名失配时列出可用项目" ($html -match '工单根目录下的项目') "失配时无提示，agent 会瞎猜"
# 项目取名：文件模式拿不到父目录名（FileSystemFileHandle 没有 parent），
# 必须用工单 title 兜底 + 重名去重，否则多个 board.json 全叫 "board"
Check "项目名重名去重" ($html -match 'function pickProjectName' -and $html -match 'used\[name\+' ) "缺少重名去重，多个 board.json 会同名"
Check "项目名优先取工单 title" ($html -match "data\.title&&data\.title!=='Aurora Board'") "项目名未取 title，文件模式会显示成 board"
Check "可重命名项目（写回 title 持久化）" ($html -match 'function renameProject' -and $html -match 'p\.data\.title=nm') "缺少重命名入口"

Write-Host "`n=== 7. 线上状态（网络可选，失败仅提示） ===" -ForegroundColor Cyan
# 7a. 线上页面优先：构建戳 + 逐字节比对。这才是部署是否成功的权威信号，
#     且不受 GitHub API 匿名配额（60 次/小时/IP）限制。
try {
  $u = "https://yutuer.github.io/aurora-board/?cb=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
  $live = (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25).Content
  $stamp = [regex]::Match($live, 'id="build-stamp">([^<]*)<').Groups[1].Value
  Check "线上构建戳非 dev: $stamp" ($stamp -ne 'dev') "线上仍是 dev"
  $lNorm = ($live -replace 'id="build-stamp">[^<]*<', 'id="build-stamp">STAMP<')
  $hNorm = ($html -replace 'id="build-stamp">[^<]*<', 'id="build-stamp">STAMP<')
  Check "线上与本地归一化后逐字节一致" ($lNorm -ceq $hNorm) "长度 $($lNorm.Length) vs $($hNorm.Length)"
} catch {
  Skip "线上页面核对" $_.Exception.Message
}
# 7b. CI 状态：API 辅助信息，超配额只提示不判失败
try {
  $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/yutuer/aurora-board/actions/runs?per_page=1' -Headers @{ 'User-Agent' = 'mavis' } -TimeoutSec 25
  $run = $r.workflow_runs[0]
  Check "CI 最新 run 为 success (sha=$($run.head_sha.Substring(0,7)))" ($run.conclusion -eq 'success') "状态 $($run.status)/$($run.conclusion)"
} catch {
  Skip "CI 状态核对（API 限流/网络问题）" $_.Exception.Message
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host ("通过 {0} 项，失败 {1} 项，跳过 {2} 项" -f $pass, $fail, $skip) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
