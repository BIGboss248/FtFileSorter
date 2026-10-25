<#
.SYNOPSIS
    Scaffolds and validates AI skills conforming to the Open Agent Skills specification.

.DESCRIPTION
    Creates standardized skill folder layouts (SKILL.md, references/, scripts/, examples/, resources/)
    or validates existing skill packages against specification requirements.

.PARAMETER Name
    The lowercase, hyphenated name of the skill (e.g. "docker-deploy").

.PARAMETER Description
    A concise description declaring what the skill does and when to use it (1-1024 chars).

.PARAMETER TargetDir
    Base directory where the skill folder will be created. Defaults to "skills".

.PARAMETER Validate
    Path to an existing skill folder to validate against the Agent Skills specification.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File ./scaffold_skill.ps1 -Name "api-auditor" -Description "Audit API routes for security and performance."
    powershell -ExecutionPolicy Bypass -File ./scaffold_skill.ps1 -Validate "skills/api-auditor"
#>

[CmdletBinding()]
param (
    [string]$Name,
    [string]$Description,
    [string]$TargetDir = "skills",
    [string]$Validate
)

function Show-Help {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  Scaffold: powershell -ExecutionPolicy Bypass -File scaffold_skill.ps1 -Name <skill-name> -Description <skill-description> [-TargetDir <dir>]"
    Write-Host "  Validate: powershell -ExecutionPolicy Bypass -File scaffold_skill.ps1 -Validate <path-to-skill-dir>`n"
    Write-Host "Parameters:"
    Write-Host "  -Name        Lowercase hyphenated name (1-64 chars, e.g. 'nextjs-deploy')"
    Write-Host "  -Description Intent-focused description of what and when (1-1024 chars)"
    Write-Host "  -TargetDir   Base directory for scaffolding (default: 'skills')"
    Write-Host "  -Validate    Path to a skill folder to validate against the specification"
}

# ----------------- VALIDATION MODE -----------------
if ($Validate) {
    Write-Host "Validating skill at: $Validate" -ForegroundColor Cyan
    $errors = @()

    if (-not (Test-Path $Validate)) {
        Write-Host "ERROR: Directory '$Validate' does not exist." -ForegroundColor Red
        exit 1
    }

    $skillFile = Join-Path $Validate "SKILL.md"
    if (-not (Test-Path $skillFile)) {
        $errors += "Missing required 'SKILL.md' file."
    } else {
        $content = Get-Content -Path $skillFile -Raw

        # Check YAML Frontmatter
        if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $errors += "SKILL.md is missing valid YAML frontmatter delimiters ('---')."
        } else {
            $frontmatter = $matches[1]

            # Extract Name
            if ($frontmatter -match 'name:\s*([^\r\n]+)') {
                $parsedName = $matches[1].Trim().Trim('"').Trim("'")
                if ($parsedName.Length -lt 1 -or $parsedName.Length -gt 64) {
                    $errors += "Skill name length ($($parsedName.Length)) must be between 1 and 64 characters."
                }
                if ($parsedName -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
                    $errors += "Skill name '$parsedName' is invalid. Must use only lowercase alphanumeric characters and single hyphens."
                }
                $dirName = (Get-Item $Validate).Name
                if ($parsedName -ne $dirName) {
                    $errors += "Skill name '$parsedName' does not match directory name '$dirName'."
                }
            } else {
                $errors += "Frontmatter is missing required 'name' field."
            }

            # Extract Description
            if ($frontmatter -match '(?s)description:\s*(?:>-\s*)?(.*?)(?:\n\w+:|$)') {
                $parsedDesc = $matches[1].Trim().Trim('"').Trim("'")
                if ($parsedDesc.Length -lt 1 -or $parsedDesc.Length -gt 1024) {
                    $errors += "Skill description length ($($parsedDesc.Length)) must be between 1 and 1024 characters."
                }
            } else {
                $errors += "Frontmatter is missing required 'description' field."
            }
        }

        # Check Line Count Budget
        $lineCount = ($content -split '\r?\n').Count
        if ($lineCount -gt 250) {
            Write-Host "WARNING: SKILL.md is $lineCount lines (recommended: <150-250 lines). Consider offloading technical details to references/ and templates to resources/templates/." -ForegroundColor Yellow
        }

        # Check relative markdown links (strip fenced code blocks and inline code spans first)
        $cleanContent = $content -replace '(?s)```.*?```', '' -replace '`.*?`', ''
        $linkMatches = [regex]::Matches($cleanContent, '\[.*?\]\(((\./|\.\./|[a-zA-Z0-9_\-\./]+)\.(md|json|ts|tsx|js|py|sh|ps1|yml|yaml))\)')
        foreach ($link in $linkMatches) {
            $relPath = $link.Groups[1].Value
            $targetPath = Join-Path $Validate $relPath
            if (-not (Test-Path $targetPath)) {
                $errors += "Broken relative link detected: '$relPath' (resolved: '$targetPath')"
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "`nValidation FAILED with $($errors.Count) error(s):" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  - $err" -ForegroundColor Red
        }
        exit 1
    } else {
        Write-Host "`nValidation PASSED! Skill conforms to Open Agent Skills specification." -ForegroundColor Green
        exit 0
    }
}

# ----------------- SCAFFOLDING MODE -----------------
if (-not $Name) {
    Show-Help
    exit 1
}

# Validate name format
if ($Name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $Name.Length -gt 64) {
    Write-Host "ERROR: Invalid name '$Name'. Must be lowercase alphanumeric with single hyphens, max 64 chars." -ForegroundColor Red
    exit 1
}

if (-not $Description) {
    $Description = "Executes $Name procedures. Use when the user asks to perform tasks related to $Name."
}

$skillPath = Join-Path $TargetDir $Name
if (Test-Path $skillPath) {
    Write-Host "ERROR: Target directory '$skillPath' already exists." -ForegroundColor Red
    exit 1
}

Write-Host "Scaffolding skill '$Name' at: $skillPath" -ForegroundColor Cyan

# Create 4-layer directories
New-Item -ItemType Directory -Path (Join-Path $skillPath "references") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $skillPath "scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $skillPath "examples") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $skillPath "resources/templates") -Force | Out-Null

# Create lean SKILL.md template (<150 lines)
$skillContent = @"
---
name: $Name
description: >-
  $Description
---

# $Name

Orchestration runbook for $Name procedures.

---

## Prerequisites & Preconditions
- [ ] Required tools and environment variables verified.
- [ ] Working workspace context loaded.

---

## Step-by-Step Execution Flow

### 1. Step One: Inspection & Setup
1. Inspect input parameters and current workspace state.
2. If optional configurations are missing, initialize safe defaults.

### 2. Step Two: Template Scaffolding
1. Inspect the starter configuration in [config.template.json](./resources/templates/config.template.json).
2. Generate target configurations from the template.
3. For in-depth rules and edge cases, consult [reference.md](./references/reference.md).

### 3. Step Three: Execution & Verification
1. Run the operational workflow.
2. Confirm outputs and state integrity.

---

## Edge Cases & AI Pitfalls
- **Common Mistake**: Watch out for subtle assumptions or hallucinated arguments.
- **State Validation**: Ensure dependencies and directories exist before running modifications.

---

## Verification & Self-Check
- [ ] Run verification tests or dry-run checks.
- [ ] Confirm no unexpected side effects occurred.
"@

Set-Content -Path (Join-Path $skillPath "SKILL.md") -Value $skillContent -Encoding UTF8

# Create starter reference file
$refContent = @"
# $Name Reference Guide

Detailed technical manual and operational deep-dive for $Name.

## Technical Specifications
- Detailed schemas, parameters, and system behaviors.
"@

Set-Content -Path (Join-Path $skillPath "references/reference.md") -Value $refContent -Encoding UTF8

# Create starter template file
$templateContent = @"
{
  "`$schema": "https://json-schema.org/draft/2020-12/schema",
  "name": "$Name",
  "version": "1.0.0"
}
"@

Set-Content -Path (Join-Path $skillPath "resources/templates/config.template.json") -Value $templateContent -Encoding UTF8

Write-Host "Skill '$Name' successfully scaffolded!" -ForegroundColor Green
Write-Host "Location: $skillPath" -ForegroundColor Green
