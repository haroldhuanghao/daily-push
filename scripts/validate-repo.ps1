[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$indexPath = Join-Path $repoRoot 'reports/index.json'
$latestPath = Join-Path $repoRoot 'reports/latest.json'
$vercelPath = Join-Path $repoRoot 'vercel.json'
$errors = [Collections.Generic.List[string]]::new()

function Test-StyleContract {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Html
    )

    $requiredMarkers = @(
        '--accent:',
        '--accent-strong:',
        '--accent-soft:',
        '--page:',
        '--surface:',
        '--text:',
        '--muted:',
        '--border:',
        '--shadow:',
        '--radius-card:',
        '--space-card:',
        ':focus-visible',
        'property="og:url"',
        'class="card'
    )

    foreach ($marker in $requiredMarkers) {
        if (-not $Html.Contains($marker)) {
            $script:errors.Add("$Label is missing required style marker: $marker")
        }
    }

    foreach ($element in @('<main', '<section', '<article', '<h1', '<h2')) {
        if (-not $Html.Contains($element)) {
            $script:errors.Add("$Label is missing semantic element: $element")
        }
    }

    if ($Html -notmatch '(?i)<html\s+lang="zh-CN"') { $script:errors.Add("$Label must declare lang=zh-CN.") }
    if ($Html -notmatch '(?i)<meta\s+name="viewport"') { $script:errors.Add("$Label is missing the viewport meta tag.") }
    if ($Html -notmatch "(?i)<link\s+[^>]*rel\s*=\s*[`"']canonical[`"']") { $script:errors.Add("$Label is missing a canonical link.") }
    if ($Html -notmatch '@media\s*\(max-width\s*:\s*900px\)') { $script:errors.Add("$Label is missing the 900px responsive breakpoint.") }
    if ($Html -notmatch '@media\s*\(max-width\s*:\s*(620|640)px\)') { $script:errors.Add("$Label is missing the mobile responsive breakpoint.") }
    if ($Html -notmatch 'overflow-x\s*:\s*auto') { $script:errors.Add("$Label is missing a safe horizontal table overflow rule.") }
    if ($Html -match '(?i)\sstyle\s*=') { $script:errors.Add("$Label contains an inline style attribute.") }
    if ($Html -match "(?i)<link\s+[^>]*rel\s*=\s*[`"']stylesheet[`"']") { $script:errors.Add("$Label must not load an external stylesheet.") }
    if ($Html -match '(?i)<script\s+[^>]*src\s*=') { $script:errors.Add("$Label must not load an external runtime script.") }
    if ($Html.Contains('<table') -and -not $Html.Contains('class="table-wrap"')) {
        $script:errors.Add("$Label contains a table outside .table-wrap.")
    }
}

function Test-EditorialContract {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [string]$ReportDirectory
    )

    if (-not $Html.Contains('name="report-contract" content="nuclear-daily-v2"')) { return }

    $requiredMarkers = @(
        '今日一句话结论', '今日重大行业事件', '智慧巡检最新动态', 'AI 视觉与多模态技术进展',
        '国产硬件与边缘智能专项', '工业数据治理与数字孪生趋势', '竞争对手动态', '商业机会',
        '持续跟踪事项', '今日技术洞察', '给公司的建议', '已确认事实', '判断', '建议行动'
    )
    foreach ($marker in $requiredMarkers) {
        if (-not $Html.Contains($marker)) { $script:errors.Add("$Label is missing required editorial content: $marker") }
    }

    # The template defines the future-report contract; it has no dated assets of its own.
    if ($Label -eq 'template') { return }

    $coverPath = Join-Path $ReportDirectory 'cover.png'
    if (-not (Test-Path -LiteralPath $coverPath)) {
        $script:errors.Add("$Label is missing required cover.png.")
    } else {
        try {
            $cover = [System.Drawing.Image]::FromFile($coverPath)
            try {
                if ($cover.Width -ne 1200 -or $cover.Height -ne 628) {
                    $script:errors.Add("$Label cover.png must be 1200x628; found $($cover.Width)x$($cover.Height).")
                }
            } finally { $cover.Dispose() }
        } catch { $script:errors.Add("$Label cover.png is not a readable image.") }
    }

    $summaryPath = Join-Path $ReportDirectory 'wecom-summary.md'
    if (-not (Test-Path -LiteralPath $summaryPath)) {
        $script:errors.Add("$Label is missing required wecom-summary.md.")
    } else {
        $summary = [IO.File]::ReadAllText($summaryPath, [Text.Encoding]::UTF8)
        if ($summary.Contains('{{') -or -not $summary.Contains("｜$Label】") -or -not $summary.Contains("/reports/$Label/")) {
            $script:errors.Add("$Label wecom-summary.md must be complete, dated, and link to its permanent path.")
        }
    }
}

try { $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw 'reports/index.json is not valid JSON.' }
try { $latest = Get-Content -LiteralPath $latestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw 'reports/latest.json is not valid JSON.' }
try { $vercel = Get-Content -LiteralPath $vercelPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw 'vercel.json is not valid JSON.' }

$templatePath = Join-Path $repoRoot 'templates/daily-report.html'
if (-not (Test-Path -LiteralPath $templatePath)) {
    $errors.Add('Missing templates/daily-report.html.')
} else {
    $templateHtml = [IO.File]::ReadAllText($templatePath, [Text.Encoding]::UTF8)
    Test-StyleContract -Label 'templates/daily-report.html' -Html $templateHtml
    Test-EditorialContract -Label 'template' -Html $templateHtml -ReportDirectory (Split-Path -Parent $templatePath)
}

$reports = @($index.reports)
if ($reports.Count -eq 0) { $errors.Add('reports/index.json contains no reports.') }

$duplicateDates = $reports | Group-Object date | Where-Object Count -gt 1
foreach ($group in $duplicateDates) { $errors.Add("Duplicate report date: $($group.Name)") }

$previousDate = $null
foreach ($report in $reports) {
    $expectedPath = "/reports/$($report.date)/"
    $filePath = Join-Path $repoRoot ("reports/{0}/index.html" -f $report.date)
    if ($report.path -ne $expectedPath) { $errors.Add("$($report.date) path must be $expectedPath") }
    if (-not (Test-Path -LiteralPath $filePath)) {
        $errors.Add("Missing report file: reports/$($report.date)/index.html")
        continue
    }
    $html = [IO.File]::ReadAllText($filePath, [Text.Encoding]::UTF8)
    if ($html.Contains('{{')) { $errors.Add("$($report.date) still contains template placeholders.") }
    if (-not $html.Contains($expectedPath)) { $errors.Add("$($report.date) page is missing its permanent path.") }
    Test-StyleContract -Label $report.date -Html $html
    Test-EditorialContract -Label $report.date -Html $html -ReportDirectory (Split-Path -Parent $filePath)
    if ($null -ne $previousDate -and $report.date -gt $previousDate) { $errors.Add('reports/index.json must be sorted by date descending.') }
    $previousDate = $report.date
}

if ($reports.Count -gt 0) {
    $expectedLatest = $reports[0]
    if ($latest.date -ne $expectedLatest.date -or $latest.path -ne $expectedLatest.path) {
        $errors.Add('reports/latest.json does not match the newest archive entry.')
    }
    $rootRedirect = @($vercel.redirects | Where-Object { $_.source -eq '/' }) | Select-Object -First 1
    if ($null -eq $rootRedirect -or $rootRedirect.destination -ne $expectedLatest.path) {
        $errors.Add('vercel.json root redirect does not target the newest report.')
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Validation passed for $($reports.Count) report(s)."
