# Unity CI/CD one-command setup (Windows PowerShell). Run from the ROOT of your Unity project's git repo.
#   irm https://raw.githubusercontent.com/Captainkor/unity-cicd-starter/main/setup-unity-cicd.ps1 | iex
$ErrorActionPreference = 'Stop'
$StarterRaw = "https://raw.githubusercontent.com/Captainkor/unity-cicd-starter/main/cicd-templates"
$Workflows  = @("ci-cd-dispatcher.yml","ci-cd-pipeline.yml","ci-cd-redeployer.yml","activation.yml","scheduled-build.yml")

Write-Host "Unity CI/CD setup"

# --- preflight ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Error "GitHub CLI (gh) not installed: https://cli.github.com"; return }
gh auth status *> $null; if ($LASTEXITCODE -ne 0) { Write-Error "Not logged in - run 'gh auth login' first."; return }
if (-not (Test-Path "ProjectSettings/ProjectVersion.txt")) { Write-Error "Run this from a Unity project root (ProjectSettings/ProjectVersion.txt not found)."; return }
$Repo = (gh repo view --json nameWithOwner -q .nameWithOwner)
if ($LASTEXITCODE -ne 0 -or -not $Repo) { Write-Error "No GitHub repo detected - is 'origin' a GitHub remote?"; return }
$Project  = Split-Path -Leaf (git rev-parse --show-toplevel)
$UnityVer = (((Select-String -Path "ProjectSettings/ProjectVersion.txt" -Pattern "m_EditorVersion:").Line -split '\s+') | Where-Object { $_ })[1]
Write-Host "   Repo:    $Repo"
Write-Host "   Project: $Project"
Write-Host "   Unity:   $UnityVer (detected; CI uses UNITY_VERSION=auto, nothing pinned)"

# --- 1. fetch workflow templates ---
Write-Host "-> Installing workflows into .github/workflows/"
New-Item -ItemType Directory -Force ".github/workflows" | Out-Null
foreach ($f in $Workflows) { Invoke-WebRequest "$StarterRaw/$f" -OutFile ".github/workflows/$f"; Write-Host "   set $f" }

# --- 2. set repository variables ---
Write-Host "-> Setting repository variables"
function Set-Var($n,$v){ gh variable set $n --repo $Repo --body $v | Out-Null; Write-Host "   $n=$v" }
Set-Var PROJECT_NAME          $Project
Set-Var UNITY_VERSION         "auto"
Set-Var EXCLUDE_UNITY_TESTS   "true"
Set-Var DEPLOY_TARGETS        "[]"
Set-Var BUILD_TARGETS         '["WebGL"]'
Set-Var USE_GIT_LFS           "false"
Set-Var MAIN_RUNNER           "ubuntu-latest"
Set-Var MACOS_RUNNER          "macos-latest"
Set-Var TIMEOUT_MINUTES_BUILD "90"

# --- 3. enable Actions ---
try { gh api -X PUT "repos/$Repo/actions/permissions" -F enabled=true -f allowed_actions=all | Out-Null; Write-Host "   Actions enabled" }
catch { Write-Host "   Could not enable Actions automatically (need repo admin) - enable in Settings -> Actions -> General." }

Write-Host ""
Write-Host "Workflows + variables installed. NEXT - set 4 secrets:"
Write-Host "  gh secret set UNITY_EMAIL    --repo $Repo"
Write-Host "  gh secret set UNITY_PASSWORD --repo $Repo"
Write-Host "  gh secret set CICD_PAT       --repo $Repo   # classic PAT: repo + workflow"
Write-Host "  Get-Content your.ulf -Raw | gh secret set UNITY_LICENSE --repo $Repo"
Write-Host ""
Write-Host "Unity license: run the 'Acquire Unity Activation File' workflow for a .alf, upload at"
Write-Host "https://license.unity3d.com/manual (un-hide Personal via the README DevTools snippet), get the .ulf."
Write-Host "Then: git add .github/workflows; git commit -m 'Add Unity CI/CD'; git push"
Write-Host "      gh workflow run ci-cd-dispatcher.yml --repo $Repo -f buildType=preview"
Write-Host "Full guide: https://github.com/Captainkor/unity-cicd-starter"
