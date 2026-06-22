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

## Enabling itch.io deploy (optional)

1. Create an itch.io **HTML** project; note your username + the project URL slug.
2. Get a [Butler API key](https://itch.io/user/settings/api_key).
3. Add secrets `BUTLER_API_KEY`, `ITCH_USERNAME`, `ITCH_PROJECT`.
4. Set variable `DEPLOY_TARGETS` = `["itch.io"]`.
5. Push a release tag — the build deploys to the itch `webgl` channel.

itch.io hosting is free (revenue share only if you *sell*). The running cost is GitHub Actions minutes (below).

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
