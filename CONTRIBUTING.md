# Contributing to Tray

Thanks for your interest! Tray is the open-source **shell** of a macOS clipboard / file-shelf / notes drawer. The UI, view model and app plumbing live here under the MIT license; the classification / inline-calc / clipboard **engine** is a separate proprietary module shipped as a binary in public releases (it builds from source in this private repo).

## Project layout

```
Sources/Tray         @main app target
Sources/TrayUI       SwiftUI drawer (contributions welcome here)
Sources/TrayChecks   CLT-runnable test/screenshot harness
Engines/DrawerEngine proprietary engine (binary in OSS release)
Packages/Core        shared modules (vendored)
```

## Dev setup

- macOS 14+, Swift 6 toolchain (Command Line Tools is enough for the dev loop; full Xcode is needed only for App Store archiving).
- Build & run:
  ```bash
  Scripts/bundle.sh --package-dir . --product Tray --name Tray \
    --bundle-id com.plainware.tray --info-plist Resources/Info.plist \
    --entitlements Resources/Tray.entitlements --icon Resources/AppIcon.icns --open
  ```
- Tests (no XCTest needed): `swift run TrayChecks ./screenshots` — must print `✅ ALL CHECKS PASSED`.

## Guidelines

- Keep UI changes in `Sources/TrayUI`. The `ScreenshotScene` must use only `ImageRenderer`-safe primitives (no `List`/`ScrollView`/segmented `Picker`/`.toolbar`).
- **Never synthesize paste.** Tray must not inject keystrokes into other apps; clips go back on the pasteboard and the user presses ⌘V themselves. Keep it sandbox-safe.
- Add a check to `Sources/TrayChecks/main.swift` for any new logic (especially classification rules and inline-calc cases).
- Match the existing style; run a build before opening a PR.
- Never commit secrets — `GoogleService-Info.plist`, `.p8`/`.p12` keys, etc. are gitignored.

## Reporting issues

Open a GitHub issue with macOS version, steps, and (if relevant) the tail of
`~/Library/Containers/com.plainware.tray/Data/Library/Logs/Plainware/Tray.log`.
