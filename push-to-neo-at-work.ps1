# Push NEO-main to neo-at-work (PowerShell)
# Run from: C:\Users\DCI-SALES-4\Desktop\NEO-main
# Requires: Git for Windows in PATH, optional GitHub CLI (gh)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot
Set-Location $RepoRoot

$RemoteName = if ($env:NEO_AT_WORK_REMOTE) { $env:NEO_AT_WORK_REMOTE } else { "neo-at-work" }
$Branch = if ($env:NEO_AT_WORK_BRANCH) { $env:NEO_AT_WORK_BRANCH } else { "main" }

Write-Host "== NEO-at-work push (PowerShell) =="
Write-Host "Root: $RepoRoot"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git not found. Install Git for Windows: https://git-scm.com/download/win"
    exit 1
}

if (-not (Test-Path .git)) {
    Write-Host "Initializing git..."
    git init -b $Branch
}

git add -A
$status = git status --porcelain
if ($status) {
    $msg = @"
NEO-at-work snapshot: v0.5 reference + NEO 1.0 design workspace

Includes complete NEO-1.0-DESIGN (19 projects review_ready), prototype
neo-next, professional scope policy template, integration plan, and
AGENT-START-HERE roadmap for home-lab implementation.
"@
    git commit -m $msg
} else {
    Write-Host "Nothing new to commit."
}

$remoteUrl = git remote get-url $RemoteName 2>$null
if (-not $remoteUrl) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "Creating private repo neo-at-work via gh..."
        gh repo create neo-at-work --private --source=. --remote=$RemoteName --push
        exit 0
    }
    Write-Host ""
    Write-Host "Add remote then push:"
    Write-Host "  git remote add $RemoteName <your-repo-url>"
    Write-Host "  git push -u $RemoteName $Branch"
    exit 1
}

git push -u $RemoteName $Branch
Write-Host "Push complete."
