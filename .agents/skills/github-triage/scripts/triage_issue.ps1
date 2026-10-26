<#
.SYNOPSIS
    CLI wrapper to manage GitHub Issues during triage operations.

.DESCRIPTION
    Provides automated operations to search, create, comment on, and close GitHub Issues
    using the GitHub CLI ('gh'). Serves as a native script fallback or alternative to MCP tools.

.PARAMETER Action
    The action to perform: 'create', 'comment', 'close', or 'search'.

.PARAMETER Title
    Title for creating an issue or searching.

.PARAMETER Body
    Markdown content for issue body or comment.

.PARAMETER IssueNumber
    The target GitHub issue number (required for 'comment' and 'close').

.PARAMETER Labels
    Comma-separated list of labels to attach when creating an issue.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .agents/skills/github-triage/scripts/triage_issue.ps1 -Action create -Title "fix(auth): handle JWT expiry" -Body "..." -Labels "bug,agent-triage"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("create", "comment", "close", "search")]
    [string]$Action,

    [string]$Title,
    [string]$Body,
    [int]$IssueNumber,
    [string]$Labels = "bug,agent-triage"
)

$ErrorActionPreference = "Continue"

$gh = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Error "GitHub CLI ('gh') is not installed or not found in PATH."
    exit 1
}

switch ($Action) {
    "search" {
        if (-not $Title) {
            Write-Error "Parameter -Title is required for search."
            exit 1
        }
        & gh issue list --search "$Title" --state open --limit 5 --json number,title,url
        break
    }

    "create" {
        if (-not $Title -or -not $Body) {
            Write-Error "Parameters -Title and -Body are required to create an issue."
            exit 1
        }
        $labelList = $Labels -split "," | ForEach-Object { $_.Trim() }
        $labelArgs = @()
        foreach ($l in $labelList) {
            $labelArgs += "--label"
            $labelArgs += $l
        }

        $url = & gh issue create --title $Title --body $Body @labelArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create issue via gh CLI."
            exit 1
        }
        Write-Host "Created issue: $url" -ForegroundColor Green
        if ($url -match '/issues/(\d+)') {
            Write-Output $matches[1]
        }
        break
    }

    "comment" {
        if (-not $IssueNumber -or -not $Body) {
            Write-Error "Parameters -IssueNumber and -Body are required to comment on an issue."
            exit 1
        }
        & gh issue comment $IssueNumber --body $Body
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to post comment on issue #$IssueNumber."
            exit 1
        }
        Write-Host "Comment posted to issue #$IssueNumber." -ForegroundColor Green
        break
    }

    "close" {
        if (-not $IssueNumber) {
            Write-Error "Parameter -IssueNumber is required to close an issue."
            exit 1
        }
        $closeArgs = @($IssueNumber)
        if ($Body) {
            $closeArgs += "--comment"
            $closeArgs += $Body
        }
        & gh issue close @closeArgs --reason completed
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to close issue #$IssueNumber."
            exit 1
        }
        Write-Host "Issue #$IssueNumber closed as completed." -ForegroundColor Green
        break
    }
}
