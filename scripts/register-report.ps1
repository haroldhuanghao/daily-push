[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Date,

    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory)]
    [ValidateLength(1, 160)]
    [string]$Summary
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$parsedDate = [DateTime]::MinValue

if (-not [DateTime]::TryParseExact($Date, 'yyyy-MM-dd', $culture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
    throw 'Date must use the YYYY-MM-DD format.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$reportPath = Join-Path $repoRoot ("reports/{0}/index.html" -f $Date)
$coverPath = Join-Path $repoRoot ("reports/{0}/cover.png" -f $Date)
$summaryPath = Join-Path $repoRoot ("reports/{0}/wecom-summary.md" -f $Date)
$indexPath = Join-Path $repoRoot 'reports/index.json'
$latestPath = Join-Path $repoRoot 'reports/latest.json'
$vercelPath = Join-Path $repoRoot 'vercel.json'
$publicPath = "/reports/$Date/"
$utf8 = [Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Report not found: reports/$Date/index.html"
}

$html = [IO.File]::ReadAllText($reportPath, [Text.Encoding]::UTF8)
if ($html.Contains('{{')) {
    throw 'The report still contains template placeholders.'
}
if (-not $html.Contains($publicPath)) {
    throw "The report metadata does not contain its permanent path: $publicPath"
}

if ($html.Contains('name="report-contract" content="nuclear-daily-v2"')) {
    $requiredMarkers = @(
        '今日一句话结论', '今日重大行业事件', '智慧巡检最新动态', 'AI 视觉与多模态技术进展',
        '国产硬件与边缘智能专项', '工业数据治理与数字孪生趋势', '竞争对手动态', '商业机会',
        '持续跟踪事项', '今日技术洞察', '给公司的建议', '已确认事实', '判断', '建议行动'
    )
    foreach ($marker in $requiredMarkers) {
        if (-not $html.Contains($marker)) { throw "The report is missing required editorial content: $marker" }
    }
    if (-not (Test-Path -LiteralPath $coverPath)) { throw "Missing required cover: reports/$Date/cover.png" }
    try {
        $cover = [System.Drawing.Image]::FromFile($coverPath)
        try {
            if ($cover.Width -ne 1200 -or $cover.Height -ne 628) {
                throw "cover.png must be 1200x628; found $($cover.Width)x$($cover.Height)."
            }
        } finally { $cover.Dispose() }
    } catch {
        throw "Invalid cover image for reports/$($Date): $($_.Exception.Message)"
    }
    if (-not (Test-Path -LiteralPath $summaryPath)) { throw "Missing required WeCom summary: reports/$Date/wecom-summary.md" }
    $wecomSummary = [IO.File]::ReadAllText($summaryPath, [Text.Encoding]::UTF8)
    if ($wecomSummary.Contains('{{') -or -not $wecomSummary.Contains("｜$Date】") -or -not $wecomSummary.Contains($publicPath)) {
        throw 'wecom-summary.md must be complete, dated, and link to this report permanent path.'
    }
}

$index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
$existingReports = @($index.reports | Where-Object { $_.date -ne $Date })
$record = [pscustomobject][ordered]@{
    date = $Date
    title = $Title
    summary = $Summary
    path = $publicPath
}
$reports = @($existingReports + $record | Sort-Object -Property date -Descending)
$updatedAt = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-ddTHH:mm:sszzz')
$newIndex = [pscustomobject][ordered]@{ updatedAt = $updatedAt; reports = $reports }
[IO.File]::WriteAllText($indexPath, ($newIndex | ConvertTo-Json -Depth 5) + "`n", $utf8)

$latest = $reports | Select-Object -First 1
[IO.File]::WriteAllText($latestPath, ($latest | ConvertTo-Json -Depth 3) + "`n", $utf8)

$vercel = Get-Content -LiteralPath $vercelPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rootRedirect = @($vercel.redirects | Where-Object { $_.source -eq '/' }) | Select-Object -First 1
if ($null -eq $rootRedirect) {
    $rootRedirect = [pscustomobject][ordered]@{ source = '/'; destination = $latest.path; permanent = $false }
    $vercel.redirects = @($rootRedirect) + @($vercel.redirects)
} else {
    $rootRedirect.destination = $latest.path
    $rootRedirect.permanent = $false
}
[IO.File]::WriteAllText($vercelPath, ($vercel | ConvertTo-Json -Depth 8) + "`n", $utf8)

Write-Host "Registered $Date; the root redirect now targets $($latest.path)"
