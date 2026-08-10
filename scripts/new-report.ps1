[CmdletBinding()]
param(
    [string]$Date = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$parsedDate = [DateTime]::MinValue

if (-not [DateTime]::TryParseExact($Date, 'yyyy-MM-dd', $culture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
    throw 'Date must use the YYYY-MM-DD format.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $repoRoot 'templates/daily-report.html'
$reportDirectory = Join-Path $repoRoot ("reports/{0}" -f $Date)
$reportPath = Join-Path $reportDirectory 'index.html'
$summaryPath = Join-Path $reportDirectory 'wecom-summary.md'

if (Test-Path -LiteralPath $reportPath) {
    throw "Report already exists; refusing to overwrite reports/$Date/index.html"
}

$zhCulture = [Globalization.CultureInfo]::GetCultureInfo('zh-CN')
$dateCn = $parsedDate.ToString('D', $zhCulture)
$weekday = $parsedDate.ToString('dddd', $zhCulture)
$content = [IO.File]::ReadAllText($templatePath, [Text.Encoding]::UTF8)
$content = $content.Replace('{{DATE}}', $Date)
$content = $content.Replace('{{DATE_CN}}', $dateCn)
$content = $content.Replace('{{WEEKDAY}}', $weekday)

[IO.Directory]::CreateDirectory($reportDirectory) | Out-Null
[IO.File]::WriteAllText($reportPath, $content, [Text.UTF8Encoding]::new($false))

$summary = @"
【核电智慧巡检与工业智能化行业日报｜$Date】

今日新增判断：
1. {{新增判断 1：仅填写可核验的实质进展}}
2. {{新增判断 2：AI、国产算力或边缘部署动态}}
3. {{新增判断 3：竞争或商机结论}}

建议动作：
- {{最优先行动 1}}
- {{最优先行动 2}}

阅读全文：
https://daily.851473.xyz/reports/$Date/
"@
[IO.File]::WriteAllText($summaryPath, $summary, [Text.UTF8Encoding]::new($false))

Write-Host "Created reports/$Date/index.html and wecom-summary.md. Replace all remaining placeholders, generate cover.png (1200x628), then register."
