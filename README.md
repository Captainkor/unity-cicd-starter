# Unity CI/CD Starter

Drop-in **GitHub Actions CI/CD for Unity projects** — automated WebGL build (plus optional tests,
releases, and itch.io/Pages deploy) on manual dispatch, version tags, PRs, or a weekly schedule.
Built on [GameCI](https://game.ci) via a pinned fork of
[Avalin/Unity-CI-CD](https://github.com/Avalin/Unity-CI-CD).

Made for **student projects**: one command to set up, and **nothing is pinned to a specific Unity
version** — each project auto-detects its own (`UNITY_VERSION=auto`).

---

## Quick start

Prereqs: your Unity project is already a **GitHub repo**, you have the [GitHub CLI](https://cli.github.com)
installed, and you've run `gh auth login`. You need **admin** on the repo (to set secrets/variables).

From your **project root**:

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/Captainkor/unity-cicd-starter/main/setup-unity-cicd.sh | bash
```
**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Captainkor/unity-cicd-starter/main/setup-unity-cicd.ps1 | iex
```

The script installs the workflows into `.github/workflows/`, sets the repo variables, and enables
Actions. Then do the two manual steps below (secrets + license), commit, and build.

> Prefer to do it by hand? Copy the files from [`cicd-templates/`](cicd-templates) into your
> `.github/workflows/` and set the variables in §[Variables](#repository-variables).

---

## Set 4 secrets

`Settings → Secrets and variables → Actions → Secrets` (or `gh secret set <NAME> --repo <you/repo>`):

| Secret | What |
|--------|------|
| `UNITY_EMAIL` | Your Unity account email. |
| `UNITY_PASSWORD` | Your Unity account password. |
| `UNITY_LICENSE` | Contents of your Unity `.ulf` (see below). |
| `CICD_PAT` | A **classic** [PAT](https://github.com/settings/tokens/new) with scopes **`repo`** + **`workflow`**. The dispatcher uses it to trigger the pipeline. |

### Getting `UNITY_LICENSE` (Unity Personal — free)

Unity 6 has no `.ulf` on disk, and Unity removed Personal from its manual-activation page, so:

1. **Generate a `.alf`** — run the **🔑 Acquire Unity Activation File** workflow (Actions tab) and
   download the `Unity_Activation_File` artifact. *(Or locally:
   `"<UnityEditor>/Unity.exe" -batchmode -nographics -quit -createManualActivationFile`.)*
2. Go to **https://license.unity3d.com/manual**, sign in, and upload the `.alf`. If only a serial
   field shows, open **DevTools → Console** and run:
   ```js
   document.querySelectorAll('.option-personal,[class*="personal" i]').forEach(e => e.style.display = '')
   ```
   Then pick **Unity Personal Edition** and download the `.ulf`.
3. Save it:
   ```bash
   gh secret set UNITY_LICENSE --repo <you/repo> < your.ulf      # PowerShell: Get-Content your.ulf -Raw | gh secret set ...
   ```

> Personal `.ulf` files expire periodically — when CI starts failing on license activation, repeat this.

---

## Running builds

- **Manual:** Actions → **⚙️ CI/CD Dispatcher** → *Run workflow* → `buildType: preview`. The WebGL
  build lands in the run's **Artifacts** (scroll to the bottom of the run page).
- **Weekly:** **🗓️ Weekly Preview Build** runs Mondays 09:00 UTC (edit the cron in `scheduled-build.yml`).
- **Release + deploy:** push a SemVer tag (`git tag v0.1.0 && git push origin v0.1.0`).

A `preview` build only builds (no release/deploy/notify). Those run only for release tags.

### Play a WebGL build locally
WebGL needs an HTTP server **and** these builds are Brotli-compressed, so a plain server fails with
`SyntaxError: illegal character U+FFFD`. Save this as `server.js` next to `index.html`, run `node server.js`:
```js
const http=require('http'),fs=require('fs'),path=require('path'),root=__dirname,port=3000;
const MIME={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.json':'application/json','.css':'text/css','.png':'image/png','.ico':'image/x-icon','.data':'application/octet-stream'};
const r=f=>{let n=f,e=null;if(n.endsWith('.br')){e='br';n=n.slice(0,-3)}else if(n.endsWith('.gz')){e='gzip';n=n.slice(0,-3)}return{t:MIME[path.extname(n).toLowerCase()]||'application/octet-stream',e}};
http.createServer((q,s)=>{let u=decodeURIComponent(q.url.split('?')[0]);if(u==='/')u='/index.html';fs.readFile(path.join(root,u),(err,d)=>{if(err){s.writeHead(404);return s.end('404')}const{t,e}=r(u);const h={'Content-Type':t};if(e)h['Content-Encoding']=e;s.writeHead(200,h);s.end(d)})}).listen(port,()=>console.log('http://localhost:'+port));
```

---

## Build targets — add or change platforms

The **`BUILD_TARGETS`** variable (a JSON array) drives the build matrix — each target builds in
parallel and produces its own artifact. It's used by the weekly schedule and tag builds too.

```bash
# e.g. add Windows alongside WebGL:
gh variable set BUILD_TARGETS --repo <you/repo> --body '["WebGL","StandaloneWindows64"]'
```
(Or edit it under Settings → Secrets and variables → Actions → Variables; or override it per run when
you manually dispatch the **⚙️ CI/CD Dispatcher**.)

| `BUILD_TARGETS` value | Runner (cost) | itch channel | Notes |
|----------------------|---------------|--------------|-------|
| `WebGL` | ubuntu (1×) | `webgl` | Browser-playable. Default. |
| `StandaloneWindows64` | ubuntu (1×) | `windows-64` | Downloadable. |
| `StandaloneLinux64` | ubuntu (1×) | `linux-client` | Downloadable. |
| `StandaloneOSX` | **macOS (10×)** | `osx-desktop` | Needs `MACOS_RUNNER`. |
| `Android` | ubuntu (1×) | `android` | Needs keystore/signing for store builds. |
| `iOS` | **macOS (10×)** | `osx-ios` | Needs Apple Developer signing (+ App Store keys for TestFlight). |

> ⚠️ **Cost:** `StandaloneOSX` and `iOS` use macOS runners billed at **10× minutes** (a 30-min build
> = 300 billed minutes) — add them only when needed. WebGL/Windows/Linux/Android stay at 1×.
> Authoritative list: [Avalin Supported-Platforms wiki](https://github.com/Avalin/Unity-CI-CD/wiki/Supported-Platforms).

## Deploying to itch.io

Off by default (`DEPLOY_TARGETS=[]`). To publish on every release:

1. **Create the itch.io project** (Dashboard → *Create new project*). Set **Kind of project = HTML**
   for a browser-playable WebGL build (use **Downloadable** for native builds). Note your username and
   the project **URL slug** — the `<slug>` in `https://<username>.itch.io/<slug>`. Keep it
   Draft/Restricted until you're ready.
2. **Get a Butler API key:** https://itch.io/user/settings/api_key.
3. **Add secrets:** `BUTLER_API_KEY`, `ITCH_USERNAME`, `ITCH_PROJECT` (the slug).
4. **Enable it:** set `DEPLOY_TARGETS` = `["itch.io"]`.
5. **Release:** push a SemVer tag (`git tag v0.1.0 && git push origin v0.1.0`) or dispatch with
   `buildType: release_candidate`. (Deploy never runs for `preview`.)

**How it maps:** each build target is pushed with `butler` to its **own channel** on the *same* itch
project (see the channel column above), versioned via `--userversion` (your tag/CI version). So
`BUILD_TARGETS=["WebGL","StandaloneWindows64"]` populates both the `webgl` (playable) and `windows-64`
(download) channels on one page. You can also deploy to several destinations at once, e.g.
`DEPLOY_TARGETS=["itch.io","gh-pages"]` (GitHub Pages is WebGL-only and needs a paid plan for private repos).

> itch.io hosting + Butler are **free** — a revenue share applies only if you *sell* the game. The only
> running cost is the GitHub Actions build minutes (below).

---

## Repository variables

Set by the setup script; tweak any time under `Settings → Secrets and variables → Actions → Variables`.

| Variable | Default | Notes |
|----------|---------|-------|
| `PROJECT_NAME` | repo name | |
| `UNITY_VERSION` | `auto` | Auto-detected from `ProjectVersion.txt`. Pin a version only if you must. |
| `EXCLUDE_UNITY_TESTS` | `true` | Set `false` if you have EditMode/PlayMode tests. |
| `DEPLOY_TARGETS` | `[]` | `[]` = artifacts only. `["itch.io"]` to deploy. |
| `BUILD_TARGETS` | `["WebGL"]` | JSON array. Add `"StandaloneWindows64"` etc. (avoid macOS — 10× minutes). |
| `USE_GIT_LFS` | `false` | Set `true` if your repo uses Git LFS. |
| `MAIN_RUNNER` / `MACOS_RUNNER` | `ubuntu-latest` / `macos-latest` | |
| `TIMEOUT_MINUTES_BUILD` | `90` | Cold WebGL builds take ~55 min on the 2-core runner. |

---

## ⚠️ Cost (GitHub Actions minutes)

Private repos have **limited free minutes** (Free = 2,000/month, Pro/Team = 3,000), **shared across
the whole account's private repos**. Unity builds are heavy: cold WebGL ≈ 55 min, warm (cached) ≈
15–25 min. Triggers: manual, release tags, the weekly schedule (~4/mo), and **non-draft PRs** touching
`Assets/`/`Packages/`/`ProjectSettings/`/`Tests/`. Overage = $0.008/min (Linux). Keep it cheap:
WebGL-only (no macOS 10×), lean on the `Library` cache, trim the weekly schedule, or use a self-hosted
runner (0 billed minutes) via `MAIN_RUNNER`. **Public repos get unlimited free minutes.**

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Dispatcher fails at "Validate Required GitHub Secrets" | A required secret is missing/empty. |
| `Build failed with exit code 125` / `no space left on device` | Runner disk — these templates already set `checkFreeDiskSpace: 'always'` (the build step is pinned to the engine's `@main`). |
| `The job has exceeded the maximum execution time` | Raise `TIMEOUT_MINUTES_BUILD`. |
| Build log: `Error while reading movie: *.mov` / `Can't create LinuxVideoMedia` | Linux Unity can't import `.mov`. Non-fatal; convert to `.webm`/`.mp4` (video) or `.ogg`/`.wav` (audio). |
| Browser: `SyntaxError: illegal character U+FFFD` | Static server isn't sending `Content-Encoding: br` — use the `server.js` above. |
| Summary table shows a false **❌ Build failed** on a green run | Already fixed here: `ci-cd-pipeline.yml` grants `actions: read` so the summary's `gh run download` works. (Upstream Avalin lacks this.) |
| Weekly build stopped firing | GitHub disables schedules after 60 days of repo inactivity — re-enable in the Actions tab. |
| Build fails on license activation (was working) | Personal `.ulf` expired — regenerate it (above). |

---

## How it works

```
ci-cd-dispatcher.yml   manual / tag / PR / weekly  →  validates, prepares metadata, tags,
      │                                                 then (via CICD_PAT) triggers:
ci-cd-pipeline.yml     test → build → release → deploy → notify
      └─ build → WebGL artifact   (engine: Captainkor/Unity-CI-CD, a pinned fork of Avalin)
activation.yml         one-off: generate a Unity .alf (version auto-detected)
scheduled-build.yml    weekly cron → dispatches a preview build
```

The engine (reusable `step-*` workflows) lives in the [`Captainkor/Unity-CI-CD`](https://github.com/Captainkor/Unity-CI-CD)
fork so it's stable and survives upstream changes. The caller workflows here are version-agnostic;
all project specifics come from the variables + secrets you set.
