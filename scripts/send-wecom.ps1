[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Date,

    [string]$BaseUrl = $(if ($env:DAILY_BASE_URL) { $env:DAILY_BASE_URL.TrimEnd('/') } else { 'https://daily.851473.xyz' }),

    [string]$WebhookUrl = $env:WECOM_WEBHOOK_URL,

    [switch]$SkipLinkCheck
)

$ErrorActionPreference = 'Stop'

# PowerShell does not load .env.local automatically. Respect an explicit parameter
# or process environment variable first, then use the git-ignored local file.
if ([string]::IsNullOrWhiteSpace($WebhookUrl)) {
    $localEnvPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.env.local'
    if (Test-Path -LiteralPath $localEnvPath) {
        foreach ($line in [IO.File]::ReadAllLines($localEnvPath, [Text.Encoding]::UTF8)) {
            if ($line -match '^\s*WECOM_WEBHOOK_URL\s*=\s*(.+?)\s*$') {
                $WebhookUrl = $matches[1].Trim().Trim('"').Trim("'")
                break
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($WebhookUrl)) {
    throw 'WECOM_WEBHOOK_URL is not configured.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$index = Get-Content -LiteralPath (Join-Path $repoRoot 'reports/index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$report = @($index.reports | Where-Object { $_.date -eq $Date }) | Select-Object -First 1
if ($null -eq $report) {
    throw "The archive does not contain $Date; push cancelled."
}

$reportUrl = "$($BaseUrl.TrimEnd('/'))$($report.path)"
if (-not $SkipLinkCheck) {
    try {
        $response = Invoke-WebRequest -Uri $reportUrl -Method Get -UseBasicParsing
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) { throw 'bad status' }
    } catch {
        throw 'The permanent report URL is not available yet. Wait for deployment and retry.'
    }
}

$payload = [pscustomobject]@{
    msgtype = 'template_card'
    template_card = [pscustomobject]@{
        card_type = 'text_notice'
        source = [pscustomobject]@{
            desc = '核电智慧巡检与工业智能化行业日报'
            desc_color = 0
        }
        main_title = [pscustomobject]@{
            title = $report.title
            desc = $report.summary
        }
        emphasis_content = [pscustomobject]@{
            title = '日报已发布'
            desc = '查看行业判断与建议行动'
        }
        sub_title_text = $report.summary
        horizontal_content_list = @(
            [pscustomobject]@{ keyname = '日报日期'; value = $report.date }
            [pscustomobject]@{ keyname = '访问方式'; value = '永久链接' }
        )
        jump_list = @(
            [pscustomobject]@{ type = 1; url = $reportUrl; title = '阅读全文' }
        )
        card_action = [pscustomobject]@{ type = 1; url = $reportUrl }
    }
} | ConvertTo-Json -Depth 8 -Compress

try {
    $result = Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload))
} catch {
    throw 'The WeCom request failed. The webhook URL was not printed; check network and bot configuration.'
}

if ($null -ne $result.errcode -and [int]$result.errcode -ne 0) {
    throw "WeCom rejected the message with error code $($result.errcode)."
}

Write-Host "Pushed $($report.title)"
