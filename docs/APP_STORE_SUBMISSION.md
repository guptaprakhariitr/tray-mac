# Tray → Mac App Store: Submission Runbook

This repo is **fully prepared** for the Mac App Store. On a Mac with full Xcode + your Apple Developer signing set up, run the prompt below (or follow the manual steps). The agent does everything up to Apple's human-only gates.

---

## ▶ PROMPT — paste this into Claude Code on your signing machine

> You are releasing the macOS app **Tray** (this repo) to the **Mac App Store**. Everything is pre-built: `project.yml` (XcodeGen), `ExportOptions-appstore.plist`, `fastlane/` (Fastfile + metadata + screenshots), `Resources/` (Info.plist, entitlements, Assets.xcassets app icon, PrivacyInfo.xcprivacy), and `Scripts/release-appstore.sh`. Do the following, pausing to ask me whenever a step needs my Apple account in the browser:
>
> 1. **Check prereqs:** confirm `xcodebuild -version`, `xcodegen --version`, `fastlane --version`, and that I'm signed into Xcode with my Apple Developer team. If `xcodegen`/`fastlane` are missing, `brew install xcodegen fastlane`.
> 2. **Confirm identifiers with me:** my **Team ID** (`DEVELOPMENT_TEAM`), the **bundle id** (default `com.plainware.tray` — keep it so the Firebase config still matches), and my **App Store Connect API key** (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` to the `.p8`). Export them as env vars.
> 3. **Firebase config:** confirm `Resources/GoogleService-Info.plist` exists (it's gitignored). It's only needed if Firebase is enabled; the shipped build does not link Firebase, so it's optional. Don't commit it.
> 4. **App record:** check App Store Connect for an app with my bundle id. If missing, create it (`fastlane produce -u $APPLE_ID -a com.plainware.tray --skip_itc false --app_name Tray` or via the web UI). Tell me if I still need to accept the **Paid/Free Apps agreement** or **tax & banking** — those are mine to do in the browser.
> 5. **Build:** run `Scripts/release-appstore.sh` (sets up the Xcode project and produces `build/Tray.pkg`). Fix any signing errors and report them to me.
> 6. **Upload:** `fastlane mac upload` (uploads binary + the metadata in `fastlane/metadata` + screenshots in `fastlane/screenshots`). It will NOT submit for review.
> 7. **Verify in App Store Connect:** tell me the build is processing, and which fields still need my input (pricing/availability, age rating questionnaire, export-compliance answer — Info.plist already declares `ITSAppUsesNonExemptEncryption=false`, App Privacy = "Data Not Collected").
> 8. **Stop before "Submit for Review"** and hand back to me to click submit, unless I tell you to run `fastlane deliver --submit_for_review`.
>
> Read `~/Library/Containers/com.plainware.tray/Data/Library/Logs/Plainware/Tray.log` if you need to debug the running app. Don't commit secrets.

---

## Prerequisites (signing machine)
- **Full Xcode** (not just Command Line Tools) + an **Apple Developer Program** membership.
- Tools: `brew install xcodegen fastlane`.
- Signing: Apple Distribution + Mac Installer Distribution certificates (Xcode "Automatically manage signing" with your team handles this), and an **App Store Connect API key** (`.p8` + Key ID + Issuer ID) created in App Store Connect → Users and Access → Integrations.
- `Resources/GoogleService-Info.plist` (gitignored) if you intend to enable Firebase later — optional for the store build.

## One-time App Store Connect setup (human-only)
1. Accept the **Apple Developer Program License Agreement** and the **Paid/Free Apps agreement**; complete **tax & banking** (free apps still need the free-apps agreement signed).
2. Create the app record (bundle id `com.plainware.tray`, name **Tray**, primary language English, category **Productivity**). `fastlane produce` can do this, or the web UI.

## Build, upload, submit
```bash
export DEVELOPMENT_TEAM=ABCDE12345         # your 10-char Team ID
export APPLE_ID=you@example.com
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8

Scripts/release-appstore.sh     # → build/Tray.pkg
fastlane mac upload             # binary + metadata + screenshots (no review submit)
```
Then in App Store Connect: set **pricing & availability** (Free), answer the **age-rating** questionnaire, confirm **App Privacy = Data Not Collected**, attach the build, and click **Submit for Review** (or run `fastlane deliver --submit_for_review`).

## What's already in the repo for you
| File | Purpose |
|---|---|
| `project.yml` | XcodeGen spec → `Tray.xcodeproj` (App Sandbox, app icon, version 1.0.0) |
| `Resources/Tray.entitlements` | App Sandbox + user-selected files |
| `Resources/Info.plist` | category, encryption=false, icon name, usage strings |
| `Resources/Assets.xcassets/AppIcon.appiconset` | full macOS icon set (16→1024) |
| `Resources/PrivacyInfo.xcprivacy` | privacy manifest (UserDefaults reason; no data collected) |
| `ExportOptions-appstore.plist` | `app-store` export config |
| `fastlane/Fastfile` | `mac build` / `mac upload` / `mac release` lanes |
| `fastlane/metadata/en-US` | name, subtitle, description, keywords, URLs, notes |
| `fastlane/screenshots/en-US` | 1440×900 + 2560×1600 screenshots (replace with your own anytime) |
| `Scripts/release-appstore.sh` | archive + export → `build/Tray.pkg` |

## Notes / gotchas
- **Bundle id**: if you change it from `com.plainware.tray`, also re-create the Firebase Apple app and swap `GoogleService-Info.plist` (or just leave Firebase disabled).
- **Version**: bump `MARKETING_VERSION` in `project.yml` (currently 1.0.0) and `CFBundleShortVersionString` for each release.
- **Privacy policy URL**: `fastlane/metadata/en-US/privacy_url.txt` points to a GitHub Pages URL — publish `docs/PRIVACY.md` there (enable Pages) or change it to wherever you host it; App Store requires a reachable privacy URL.
- **Screenshots**: the committed ones are generated by Tray (`swift run TrayChecks`). Replace them in `fastlane/screenshots/en-US/` with your own (valid macOS sizes: 1280×800, 1440×900, 2560×1600, 2880×1800).
