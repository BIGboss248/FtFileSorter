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

# 4. Check structured logging setup (logger + app_logger.dart)
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$loggerFile = Join-Path $repoRoot "lib/core/logging/app_logger.dart"
$hasLoggerDependency = (Test-Path $pubspecPath) -and
    (Select-String -Path $pubspecPath -Pattern '^\s+logger:' -Quiet)
$hasLoggerFile = Test-Path $loggerFile

if (-not ($hasLoggerDependency -and $hasLoggerFile)) {
    if ($Repair) {
        if (-not $hasLoggerDependency) {
            Write-Host "Adding logger dependency..." -ForegroundColor Yellow
            flutter pub add logger
        }
        if (-not $hasLoggerFile) {
            $template = Join-Path $PSScriptRoot "../resources/templates/app_logger.dart.template"
            if (Test-Path $template) {
                New-Item -ItemType Directory -Force -Path (Split-Path $loggerFile) | Out-Null
                Copy-Item $template $loggerFile
                Write-Host "Created lib/core/logging/app_logger.dart from template." -ForegroundColor Green
            } else {
                Write-Warning "Logging template not found at $template"
            }
        }
    } else {
        Write-Warning "Structured logging missing (logger dependency and/or lib/core/logging/app_logger.dart). Run scripts/verify-env.ps1 -Repair"
    }
} else {
    Write-Host "Structured logging (logger + lib/core/logging/app_logger.dart) verified." -ForegroundColor Green
}

Write-Host "Flutter environment verified successfully." -ForegroundColor Green
exit 0
