#!/usr/bin/env bash
# Unity CI/CD one-command setup. Run from the ROOT of your Unity project's git repo.
#   curl -fsSL https://raw.githubusercontent.com/Captainkor/unity-cicd-starter/main/setup-unity-cicd.sh | bash
set -euo pipefail

STARTER_RAW="https://raw.githubusercontent.com/Captainkor/unity-cicd-starter/main/cicd-templates"
WORKFLOWS=(ci-cd-dispatcher.yml ci-cd-pipeline.yml ci-cd-redeployer.yml activation.yml scheduled-build.yml)

echo "🎮 Unity CI/CD setup"

# --- preflight ---
command -v gh >/dev/null  || { echo "❌ GitHub CLI (gh) not installed: https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "❌ Not logged in — run 'gh auth login' first."; exit 1; }
[ -f ProjectSettings/ProjectVersion.txt ] || { echo "❌ Run this from a Unity project root (ProjectSettings/ProjectVersion.txt not found)."; exit 1; }
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner) || { echo "❌ No GitHub repo detected — is 'origin' a GitHub remote?"; exit 1; }
PROJECT=$(basename "$(git rev-parse --show-toplevel)")
UNITY_VER=$(grep 'm_EditorVersion:' ProjectSettings/ProjectVersion.txt | awk '{print $2}')
echo "   Repo:    $REPO"
echo "   Project: $PROJECT"
echo "   Unity:   $UNITY_VER (detected; CI uses UNITY_VERSION=auto, so nothing is pinned)"

# --- 1. fetch workflow templates ---
echo "→ Installing workflows into .github/workflows/"
mkdir -p .github/workflows
for f in "${WORKFLOWS[@]}"; do
  curl -fsSL "$STARTER_RAW/$f" -o ".github/workflows/$f" && echo "   ✓ $f"
done

# --- 2. set repository variables (admin required) ---
echo "→ Setting repository variables"
set_var(){ gh variable set "$1" --repo "$REPO" --body "$2" >/dev/null && echo "   ✓ $1=$2"; }
set_var PROJECT_NAME         "$PROJECT"
set_var UNITY_VERSION        "auto"
set_var EXCLUDE_UNITY_TESTS  "true"     # set to false if your project has EditMode/PlayMode tests
set_var DEPLOY_TARGETS       "[]"       # set to ["itch.io"] to deploy on release tags (see README)
set_var BUILD_TARGETS        '["WebGL"]'
set_var USE_GIT_LFS          "false"
set_var MAIN_RUNNER          "ubuntu-latest"
set_var MACOS_RUNNER         "macos-latest"
set_var TIMEOUT_MINUTES_BUILD "90"

# --- 3. enable Actions ---
if gh api -X PUT "repos/$REPO/actions/permissions" -F enabled=true -f allowed_actions=all >/dev/null 2>&1; then
  echo "   ✓ Actions enabled"
else
  echo "   ⚠️ Could not enable Actions automatically (need repo admin) — enable it in Settings → Actions → General."
fi

cat <<EOF

✅ Workflows + variables installed.

NEXT — set 4 secrets (yours; this script never handles them):
  gh secret set UNITY_EMAIL    --repo $REPO
  gh secret set UNITY_PASSWORD --repo $REPO
  gh secret set CICD_PAT       --repo $REPO     # classic PAT, scopes: repo + workflow
  gh secret set UNITY_LICENSE  --repo $REPO < your.ulf

Getting UNITY_LICENSE (Unity Personal is free):
  1. Run the "🔑 Acquire Unity Activation File" workflow (Actions tab) → download the .alf artifact.
  2. Upload it at https://license.unity3d.com/manual. If the Personal option is hidden, open the
     page's DevTools console and run:
       document.querySelectorAll('.option-personal,[class*="personal" i]').forEach(e=>e.style.display='')
     then pick "Unity Personal Edition" and download the .ulf.
  3. gh secret set UNITY_LICENSE --repo $REPO < the-downloaded.ulf

THEN commit the workflows and run your first build:
  git add .github/workflows && git commit -m "Add Unity CI/CD" && git push
  gh workflow run ci-cd-dispatcher.yml --repo $REPO -f buildType=preview

Full guide: https://github.com/Captainkor/unity-cicd-starter
EOF
