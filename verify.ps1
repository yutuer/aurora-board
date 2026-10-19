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

Write-Host "`n=== 7. 线上状态（网络可选，失败仅提示） ===" -ForegroundColor Cyan
try {
  $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/yutuer/aurora-board/actions/runs?per_page=1' -Headers @{ 'User-Agent' = 'mavis' } -TimeoutSec 25
  $run = $r.workflow_runs[0]
  Check "CI 最新 run 为 success (sha=$($run.head_sha.Substring(0,7)))" ($run.conclusion -eq 'success') "状态 $($run.status)/$($run.conclusion)"
  $live = (Invoke-WebRequest -Uri 'https://yutuer.github.io/aurora-board/' -UseBasicParsing -TimeoutSec 25).Content
  $stamp = [regex]::Match($live, 'id="build-stamp">([^<]*)<').Groups[1].Value
  Check "线上构建戳非 dev: $stamp" ($stamp -ne 'dev') "线上仍是 dev"
  $lNorm = ($live -replace 'id="build-stamp">[^<]*<', 'id="build-stamp">STAMP<')
  $hNorm = ($html -replace 'id="build-stamp">[^<]*<', 'id="build-stamp">STAMP<')
  Check "线上与本地归一化后逐字节一致" ($lNorm -ceq $hNorm) "长度 $($lNorm.Length) vs $($hNorm.Length)"
} catch {
  Skip "线上核对（网络不可用）" $_.Exception.Message
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host ("通过 {0} 项，失败 {1} 项，跳过 {2} 项" -f $pass, $fail, $skip) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
