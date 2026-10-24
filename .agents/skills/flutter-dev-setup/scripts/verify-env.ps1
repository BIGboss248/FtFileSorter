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

Write-Host "Flutter environment verified successfully." -ForegroundColor Green
exit 0
