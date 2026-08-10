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
$coverUrl = "$($reportUrl.TrimEnd('/'))/cover.png"
if (-not $SkipLinkCheck) {
    try {
        $response = Invoke-WebRequest -Uri $reportUrl -Method Get -UseBasicParsing
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) { throw 'bad status' }
    } catch {
        throw 'The permanent report URL is not available yet. Wait for deployment and retry.'
    }

    try {
        $coverResponse = Invoke-WebRequest -Uri $coverUrl -Method Get -UseBasicParsing
        if ($coverResponse.StatusCode -lt 200 -or $coverResponse.StatusCode -ge 400) { throw 'bad status' }
        if ($coverResponse.Headers['Content-Type'] -notlike 'image/*') { throw 'bad content type' }
    } catch {
        throw 'The permanent cover URL is not available yet. Wait for deployment and retry.'
    }
}

$payload = [pscustomobject]@{
    msgtype = 'news'
    news = [pscustomobject]@{
        articles = @(
            [pscustomobject]@{
                title = $report.title
                description = $report.summary
                url = $reportUrl
                picurl = $coverUrl
            }
        )
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

Write-Host "Pushed $($report.title) with cover $coverUrl"
