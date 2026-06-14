# Plainware suite → macOS deployment runbook (all 5 apps)

This file is identical in all five repos. It's the **orchestration layer + shared one-time setup** for shipping the whole suite. Each app also has its own detailed runbook (linked below); this tells you the order and the setup that's common to all.

> Run this on a Mac with **full Xcode** + an **Apple Developer Program** membership. The Command-Line-Tools dev loop in each repo is for development only — archiving/notarizing needs Xcode.

## The five apps
| App | Bundle id | Channel | Per-app runbook | Runtime permission |
|-----|-----------|---------|-----------------|--------------------|
| Glaze   | `com.plainware.glaze`   | Mac App Store          | `docs/APP_STORE_SUBMISSION.md` | none |
| Twinned | `com.plainware.twinned` | Mac App Store          | `docs/APP_STORE_SUBMISSION.md` | none |
| Tray    | `com.plainware.tray`    | Mac App Store          | `docs/APP_STORE_SUBMISSION.md` | Keychain (own items) |
| Caliper | `com.plainware.caliper` | Mac App Store          | `docs/APP_STORE_SUBMISSION.md` | Screen Recording |
| Swipe   | `com.plainware.swipe`   | Notarized DMG (direct) | `docs/RELEASE.md`              | Accessibility |

All five share the Firebase project **girlfeed-44107** (version-gating only — no Firebase SDK is linked; the app reads Firestore `apps/<key>` over plain HTTPS and **fails open** if offline).

## One-time shared setup (do once; applies to every app)
1. **Apple account:** in App Store Connect, accept the **Apple Developer Program License Agreement** + the **Paid/Free Apps agreement**, and complete **tax & banking** (free apps still need the free-apps agreement signed).
2. **Tools:** `brew install xcodegen fastlane create-dmg`.
3. **App Store Connect API key** (`.p8` + Key ID + Issuer ID) from App Store Connect → Users and Access → Integrations. Used by fastlane (the 4 store apps) and by notarytool (Swipe). Export once:
   ```bash
   export DEVELOPMENT_TEAM=ABCDE12345        # your 10-char Team ID
   export APPLE_ID=you@example.com
   export ASC_KEY_ID=XXXXXXXXXX
   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   export ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
   ```
4. **Signing certs** (Xcode → "Automatically manage signing" with your team will create them): **Apple Distribution** + **Mac Installer Distribution** for the store apps, and **Developer ID Application** for Swipe.
5. **Firebase config — REQUIRED per app, before building.** For each repo, download its `GoogleService-Info.plist` from the **girlfeed-44107** console (Project settings → Your apps → the matching app) and place it at `<repo>/Resources/GoogleService-Info.plist` **before** running xcodegen — it's listed in `project.yml`, so generation **fails** without it. It's gitignored; **never commit it**.
6. **Firestore version docs:** ensure girlfeed-44107 Firestore has a doc per app — `apps/glaze`, `apps/twinned`, `apps/tray`, `apps/caliper`, `apps/swipe` — each with `{ minBuild, latestBuild, forceUpdate, downloadURL }`. Seed once; this is how you force an update later without shipping a binary.
7. **Privacy URLs:** each repo's `fastlane/metadata/en-US/privacy_url.txt` points at a GitHub Pages URL. Enable **GitHub Pages** (serve `docs/PRIVACY.md`) on each repo, or change the URL — the App Store requires a reachable privacy policy.

## Order
Ship the **4 App Store apps first** (identical flow), then **Swipe** (notarize). For each App Store app, `cd` into the repo and follow its `docs/APP_STORE_SUBMISSION.md`:
```bash
# (env vars from step 3 already exported; Resources/GoogleService-Info.plist already placed)
Scripts/release-appstore.sh     # → build/<App>.pkg
fastlane mac upload             # binary + metadata + screenshots (does NOT submit for review)
```
Then in App Store Connect: **pricing = Free**, answer the **age-rating** questionnaire, **App Privacy = Data Not Collected**, **export compliance = no non-exempt encryption** (only standard, exempt OS crypto for the user's own on-device data — `ITSAppUsesNonExemptEncryption=false` is set), attach the build, **Submit for Review**.

For Swipe, `cd swipe` and follow `docs/RELEASE.md`:
```bash
Scripts/release-notarize.sh     # → build/Swipe.dmg (notarized + stapled)
xcrun stapler validate build/Swipe.dmg
gh release create v1.0.0 build/Swipe.dmg --repo guptaprakhariitr/swipe-mac \
  --title "Swipe 1.0.0" --notes "Notarized direct download."
```

## ▶ MASTER PROMPT — paste into Claude Code (from the folder that contains all 5 repos)

> I've cloned the five Plainware app repos — **glaze, twinned, tray, caliper, swipe** — side by side in this folder. Deploy all of them to macOS: the first four to the **Mac App Store**, **swipe** as a **notarized direct-download DMG**. Work **one repo at a time, in that order**.
>
> Up front, once: confirm my **Team ID**, **Apple ID**, and **App Store Connect API key** (`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH`) and export them; verify `xcodebuild`, `xcodegen`, `fastlane`, and `create-dmg` are installed (`brew install` any that are missing); and confirm I'm signed into Xcode with my team.
>
> For each repo: **first confirm I've placed `Resources/GoogleService-Info.plist`** (from the girlfeed-44107 Firebase console for that app's bundle id) — the build fails without it. Then read that repo's own runbook (`docs/APP_STORE_SUBMISSION.md`, or `docs/RELEASE.md` for swipe) and follow it **exactly**, pausing whenever a step needs my Apple account in the browser. Build, then upload (store) or notarize + create a GitHub Release (swipe). **Stop before "Submit for Review"** on each store app and hand back to me, unless I say to auto-submit.
>
> After each app, tell me: what's processing in App Store Connect (or which GitHub Release was created), and which human-only gates remain (agreements, pricing, age rating, export compliance, Submit for Review). **Never commit secrets, and never commit `GoogleService-Info.plist`.**

## Notes
- **Screenshots** in each repo are app-generated placeholders (`swift run <App>Checks docs/images`). Capture real ones at a valid macOS size (1280×800, 1440×900, 2560×1600 or 2880×1800) before final submit.
- **Free apps**, no in-app purchase to configure. Paid features exist but are gated **OFF** via Remote Config and can be turned on later with no binary change.
- **Per-app detail** always wins over this summary — open the repo's own runbook for the exact steps and gotchas.
