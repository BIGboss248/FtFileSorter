# Environment Verification Script
param (
    [switch]$Repair = $false
)

Write-Host "==> Verifying Flutter Development Environment..." -ForegroundColor Cyan

# 1. Check Flutter executable
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter CLI not found in PATH."
    exit 1
}

# 2. Check desktop configuration
$configOut = flutter config | Out-String
if ($configOut -notmatch "enable-windows-desktop: true") {
    if ($Repair) {
        Write-Host "Enabling Windows Desktop..." -ForegroundColor Yellow
        flutter config --enable-windows-desktop
    } else {
        Write-Warning "Windows desktop is not enabled. Run: flutter config --enable-windows-desktop"
    }
}

# 3. Check GitHub Triage Infrastructure (.github/ISSUE_TEMPLATE)
$repoRoot = (Get-Location).Path
$hasBugReport = Test-Path (Join-Path $repoRoot ".github/ISSUE_TEMPLATE/bug_report.yml")
$hasIssueConfig = Test-Path (Join-Path $repoRoot ".github/ISSUE_TEMPLATE/config.yml")
if (-not ($hasBugReport -and $hasIssueConfig)) {
    if ($Repair) {
        $initScript = Join-Path $PSScriptRoot "init_triage_infra.ps1"
        if (Test-Path $initScript) {
            & $initScript
        }
    } else {
        Write-Warning "GitHub Triage templates (.github/ISSUE_TEMPLATE/bug_report.yml & config.yml) missing. Run scripts/init_triage_infra.ps1"
    }
} else {
    Write-Host "GitHub Triage infrastructure (.github/ISSUE_TEMPLATE/) verified." -ForegroundColor Green
}

Write-Host "Flutter environment verified successfully." -ForegroundColor Green
exit 0
