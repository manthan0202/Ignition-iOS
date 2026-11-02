# Claude review — Step 01: reproducible build checks

## Why this is the first step
The 17-page independent review, "Ignition: back to the drawing board" (Nov 1, 2026),
places tooling first. Repeatedly packaging revisions without compiling them on macOS
leaves real iPhone errors to be discovered only by the user.

## Scope (only this step)
- `.github/workflows/ignition-preview-ci.yml` — GitHub Actions workflow on `macos-26`
- `Scripts/ci_smoke_preview.sh` — launches the Preview app in the iPhone Simulator and saves one screenshot
- `STEP_01_BUILD_VERIFICATION.md` — this guide

**All existing app Swift source, Xcode project settings, screens, assets and designs are unchanged.**
This is a new working copy; the November 1 Home drawer ZIP stays frozen.

## What the workflow verifies after you upload to GitHub
1. The existing `Scripts/verify_revision.sh` deterministic test suite passes.
2. `Ignition-Preview` compiles against an actual iOS SDK without code signing.
3. A simulator can install and launch `IgnitionPreview.app`.
4. A Home screenshot and build/test logs are uploaded as downloadable workflow artifacts.

## What it does NOT verify
- Physical-device gestures and smoothness, Family Controls shielding or entitlements
- Lock Screen and Dynamic Island in real world states
- Visual correctness (screenshot is diagnostic, not automatically compared with a gold image)
- Production signing, App Store submission, or the `Ignition-Full` scheme

## To activate GitHub Actions (one-time setup)
1. Create a **private** GitHub repository. Keep it private unless you explicitly wish to publish your code/assets.
2. Unzip this archive, open its `Ignition` folder and upload its CONTENTS as the
   repository root. Do **not** upload the outer `Ignition` directory as a single nested folder,
   or GitHub will not locate `.github/workflows` at the repository root.
3. Commit to `main`. Go to GitHub > Actions > Ignition Preview — Compile and Smoke Test.
4. Read whether the run succeeded. Download its `ignition-preview-ci-...` artifact for
   `xcodebuild-preview.log`, `foundation-tests.log`, and `ignition-preview-home.png`.
5. If it fails, do not move to Step 02: share the first compiler error, not a screenshot of the end of the log.

This workflow uses hosted GitHub macOS runners. Running CI may consume billable runner minutes,
particularly in private repositories. No repository was created and nothing was pushed.

## Local checks performed by this assistant
- Existing deterministic suite executed with Linux Swift 6.2.1: PASS.
- New shell script parsed with `bash -n` and YAML parsed: PASS.
- File preservation check ensures app source/Xcode project assets unchanged: PASS.
- macOS Xcode build, Simulator launch and screenshot: NOT RUN (no Xcode or iOS runtime here).

## Next step, only after CI gate
Step 02: Prototype the shared journey-world time/path/camera contract in an isolated
module and prove it can keep path, pins, Now and footprints aligned at all zooms.
The product decision about map prominence (Startline+ vs larger landscape) stays open.
