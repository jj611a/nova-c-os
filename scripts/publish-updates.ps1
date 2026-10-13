# Publish Nova-C updates: build + sign the APT repository in WSL, then push it to the gh-pages branch that
# GitHub Pages serves at https://jj611a.github.io/nova-c-os/. Every installed Nova-C OS picks the update up
# (apt-daily + unattended-upgrades) within about a day, or at once with: sudo apt update && sudo apt full-upgrade
# Before publishing: bump Version in packages/<name>/control (and VERSION_ID in os-release for a new OS version).
# Usage: powershell -File scripts\publish-updates.ps1 [-Message "nova-c-desktop 0.1.1: ..."]
param(
    [string]$Site = (Join-Path $PSScriptRoot "..\..\nova-c-os-pages"),
    [string]$Message = "Publish Nova-C OS updates"
)
# git and wsl write progress to stderr, which Windows PowerShell 5.1 turns into errors: check exit codes instead
$ErrorActionPreference = "Continue"
function Check($what) { if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)" } }
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$remote = (git -C $repo remote get-url origin); Check "git remote"

# gh-pages checkout next to the source repo (created on first run)
if (-not (Test-Path (Join-Path $Site ".git"))) {
    New-Item -ItemType Directory -Force $Site | Out-Null
    git -C $Site init -q -b gh-pages; Check "git init"
    git -C $Site remote add origin $remote; Check "git remote add"
    git -C $Site fetch -q origin gh-pages 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { git -C $Site reset -q --hard origin/gh-pages; Check "git reset" }
} else {
    git -C $Site pull -q --ff-only origin gh-pages 2>&1 | Out-Null; Check "git pull"
}
$Site = (Resolve-Path $Site).Path

function WslPath($p) { "/mnt/" + $p.Substring(0,1).ToLower() + ($p.Substring(2) -replace '\\','/') }
wsl -d Debian -u root -- bash (WslPath "$repo\scripts\publish-updates.sh") (WslPath $Site); Check "publish-updates.sh"

git -C $Site add -A; Check "git add"
git -C $Site diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Output "nothing changed"; exit 0 }
git -C $Site commit -q -m $Message; Check "git commit"
git -C $Site push -q -u origin gh-pages 2>&1 | ForEach-Object { "$_" }; Check "git push"
Write-Output "published: https://jj611a.github.io/nova-c-os/"
