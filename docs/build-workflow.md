# Build Workflow

## Scope

This document standardizes local build and release flow for this repository, especially the Milkdown WebView runtime pipeline.

Core rule:

- `web/milkdown/src/*` is source code.
- `assets/milkdown_web/index.html` is runtime artifact loaded by Flutter WebView.
- Source changes are not effective in App until web bundle is rebuilt and synced.

## One-Click Release Build

Use:

```bat
build_abi_release.bat
```

or (Android + Windows):

```bat
build_flutter_release.bat
```

Scripts now perform all required steps in order:

1. Run `scripts/sync_milkdown_web.bat` (Node check + `npm ci` + `npm run build` + artifact sync).
2. Run Flutter release pipeline (`flutter clean`, `flutter pub get`).
3. Build platform artifacts:
   - `build_abi_release.bat`: Android ABI APKs
   - `build_flutter_release.bat`: Android ABI APKs + Windows release
4. Open output directory/directories.

If any step fails, script exits immediately with an error.

## GitHub Actions (Auto ABI Release Build)

Repository now includes workflow:

- `.github/workflows/build-android-abi-release.yml`

Triggers:

- Manual trigger: `workflow_dispatch`
- Tag trigger: push tags matching `v*` (for example `v1.4.0`)

Pipeline steps are aligned with `build_abi_release.bat`:

1. Build Milkdown web bundle (`npm ci` + `npm run build` in `web/milkdown`).
2. Sync `web/milkdown/dist/index.html` to `assets/milkdown_web/index.html`.
3. Run Flutter release pipeline (`flutter clean`, `flutter pub get`, `flutter build apk --release --split-per-abi`).
4. Upload generated APKs from `build/app/outputs/flutter-apk/*.apk` as workflow artifacts.

## Why This Is Required

Flutter runtime loads web editor from:

- `assets/milkdown_web/index.html`

It does not load directly from:

- `web/milkdown/src/main.js`
- `web/milkdown/src/style.css`

Therefore, changing only `src/*` without rebuilding web artifact causes "code changed but not effective" issues.

## Manual Flow (If Needed)

For debugging or step-by-step execution:

```bat
scripts\sync_milkdown_web.bat
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
flutter build windows --release
```

## Daily Development Notes

- Web source iteration:
  - edit `web/milkdown/src/main.js`, `web/milkdown/src/style.css`
  - run `npm run build`
  - sync artifact to `assets/milkdown_web/index.html`
- Before release build:
  - Android only: run `build_abi_release.bat`
  - Android + Windows: run `build_flutter_release.bat`
  - do not skip web build step.

## Commit Hygiene

When web source is changed, include all relevant files in one commit:

- `web/milkdown/src/main.js` (if changed)
- `web/milkdown/src/style.css` (if changed)
- `assets/milkdown_web/index.html` (rebuilt artifact)

Do not commit:

- `web/milkdown/node_modules/`
- `web/milkdown/dist/`

These are already ignored by `.gitignore`.

## Fast Troubleshooting

### Symptom: App behavior unchanged after web source edit

Checklist:

1. Did `npm run build` succeed in `web/milkdown`?
2. Was `dist/index.html` copied to `assets/milkdown_web/index.html`?
3. Did you relaunch app after updating assets?

### Symptom: `build_abi_release.bat` fails at step 0

Cause:

- Node.js missing or not in PATH.

Fix:

- Install Node.js LTS and reopen terminal.
- Verify using `node -v` and `npm -v`.
