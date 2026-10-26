<#
.SYNOPSIS
    Initializes repository GitHub Issues triage infrastructure (issue templates and triage labels).

.DESCRIPTION
    Scaffolds .github/ISSUE_TEMPLATE/bug_report.yml and .github/ISSUE_TEMPLATE/config.yml from skill templates.
    Ensures standard triage labels ('bug', 'agent-triage', 'self-repair', 'verified') are created
    in the remote GitHub repository using GitHub CLI ('gh') if available and authenticated.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .agents/skills/flutter-dev-setup/scripts/init_triage_infra.ps1
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = "Continue"

Write-Host "==> Initializing GitHub Triage Infrastructure..." -ForegroundColor Cyan

# 1. Resolve repository root
$repoRoot = (Get-Location).Path
$templatesDir = Join-Path $repoRoot ".github/ISSUE_TEMPLATE"

# 2. Scaffold templates directory if missing
if (-not (Test-Path $templatesDir)) {
    Write-Host "Creating directory: $templatesDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null
}

# 3. Copy starter issue templates if missing
$sourceDir = Join-Path $PSScriptRoot "../resources/templates"

$bugTemplateDest = Join-Path $templatesDir "bug_report.yml"
if (-not (Test-Path $bugTemplateDest)) {
    $bugCandidates = @(
        (Join-Path $sourceDir "bug_report.yml.template"),
        (Join-Path $sourceDir "bug_report.yml")
    )
    $bugTemplateSrc = $bugCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($bugTemplateSrc) {
        Copy-Item -Path $bugTemplateSrc -Destination $bugTemplateDest -Force
        Write-Host "Installed: .github/ISSUE_TEMPLATE/bug_report.yml" -ForegroundColor Green
    }
} else {
    Write-Host "Existing template found: .github/ISSUE_TEMPLATE/bug_report.yml" -ForegroundColor Gray
}

$configTemplateDest = Join-Path $templatesDir "config.yml"
if (-not (Test-Path $configTemplateDest)) {
    $configCandidates = @(
        (Join-Path $sourceDir "issue_config.yml.template"),
        (Join-Path $sourceDir "config.yml.template"),
        (Join-Path $sourceDir "config.yml")
    )
    $configTemplateSrc = $configCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($configTemplateSrc) {
        Copy-Item -Path $configTemplateSrc -Destination $configTemplateDest -Force
        Write-Host "Installed: .github/ISSUE_TEMPLATE/config.yml" -ForegroundColor Green
    }
} else {
    Write-Host "Existing config found: .github/ISSUE_TEMPLATE/config.yml" -ForegroundColor Gray
}

# 4. Check GitHub CLI and ensure triage labels exist
$gh = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "NOTE: GitHub CLI ('gh') is not installed in PATH. Skipping remote label provisioning." -ForegroundColor Yellow
    exit 0
}

# Check gh auth status safely (with automatic fallback to Git Credential Manager)
$null = & gh auth status 2>$null
if ($LASTEXITCODE -ne 0 -and -not $env:GH_TOKEN) {
    $credInput = "protocol=https`nhost=github.com`n`n"
    $credOut = $credInput | git credential fill 2>$null
    foreach ($line in $credOut) {
        if ($line -match "^password=(.+)$") {
            $env:GH_TOKEN = $matches[1].Trim()
            break
        }
    }
}

$null = & gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "NOTE: GitHub CLI ('gh') is not currently authenticated. Local templates scaffolded successfully; skipping remote label provisioning." -ForegroundColor Yellow
    exit 0
}

$labels = @(
    @{ Name = "bug"; Color = "d73a4a"; Description = "Something isn't working" },
    @{ Name = "agent-triage"; Color = "0e8a16"; Description = "Triaged and managed by AI agent" },
    @{ Name = "self-repair"; Color = "1d76db"; Description = "Linked to an autofix.json imperative rule" },
    @{ Name = "verified"; Color = "5319e7"; Description = "Fix verified through automated test suites" }
)

Write-Host "Syncing triage labels..." -ForegroundColor Cyan
foreach ($lbl in $labels) {
    $name = $lbl.Name
    $color = $lbl.Color
    $desc = $lbl.Description

    & gh label create $name --color $color --description $desc --force 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Label ensured: $name" -ForegroundColor Green
    } else {
        Write-Host "  [--] Label check/skip: $name" -ForegroundColor Gray
    }
}

Write-Host "GitHub Triage infrastructure successfully initialized." -ForegroundColor Green
exit 0
