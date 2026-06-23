# Contributing

Thanks for helping improve this starter kit! It's intentionally small: thin caller
workflows, two setup scripts, and docs.

## Where things belong
- **This repo** holds the `cicd-templates/` caller workflows, `setup-unity-cicd.*`, and docs.
- **The pipeline engine** (reusable `step-*` workflows) lives in the
  [`Captainkor/Unity-CI-CD`](https://github.com/Captainkor/Unity-CI-CD) fork. Engine-level
  changes usually belong upstream in [Avalin/Unity-CI-CD](https://github.com/Avalin/Unity-CI-CD)
  (then synced into the fork).

## Before opening a PR
- Test against a **real Unity repo**: run `setup-unity-cicd.sh`, then dispatch a `preview`
  build and confirm it goes green and produces a WebGL artifact.
- Keep templates **version-agnostic** — never hardcode a Unity version (use `auto` /
  `ProjectVersion.txt`).
- If you touch `cicd-templates/`, make sure the engine refs still resolve in the fork.

## License
By contributing, you agree your contributions are licensed under the MIT License
(see [LICENSE](LICENSE)).
