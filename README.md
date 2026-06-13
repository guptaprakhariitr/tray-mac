# Tray

**Clipboard, shelf and notes in one edge drawer.** Tray keeps a searchable
**clipboard history**, a drag-and-drop **file shelf**, and a scratch **notes**
pad with inline math — all in a single native macOS drawer. A free, native,
open-source replacement for paid clipboard managers.

- 📋 Searchable clipboard history with smart kind detection (URL / color / text)
- 📌 Pin the clips you reuse most
- 🗂️ Drag-and-drop file shelf for staging files between apps
- 🧮 Quick notes with inline arithmetic (`12 * 3` → `36`)
- 🔒 100% local — nothing leaves your Mac
- 🆓 Free & open source

> Tray never synthesizes a paste keystroke. Tap a clip to put it on the
> pasteboard, then press **Cmd-V** yourself.

## Architecture

Open-source **shell** (`TrayUI`) + proprietary **engine** (`DrawerEngine`). In
the public release the engine ships as a precompiled XCFramework; here it builds
from source.

```
Sources/Tray          executable (@main)        — app entry, menus, settings
Sources/TrayUI        library (open source)     — drawer UI, view model
Engines/DrawerEngine  library (proprietary)     — clipboard store, classifier, inline calc
Packages/Core         shared modules            — design system, remote config, license, updates
```

## Build & run (no Xcode required)

```bash
swift build

Scripts/bundle.sh --package-dir . --product Tray \
  --name Tray --bundle-id com.plainware.tray \
  --info-plist Resources/Info.plist --entitlements Resources/Tray.entitlements --open
```

Run logic checks + regenerate App Store screenshots (off-screen, no permissions):
```bash
swift run TrayChecks ./screenshots
```

## Engine API (`DrawerEngine`)

```swift
enum ClipKind: String, Sendable { case text, url, color, image }
struct ClipItem: Identifiable, Sendable { id; kind; text; date; pinned }

func classify(_ s: String) -> ClipKind          // URL / hex color / text
func evaluateInline(_ line: String) -> String?   // "12*3" -> "36", "hello" -> nil

@MainActor final class ClipboardStore: ObservableObject {
    @Published var items: [ClipItem]
    func add(_ text: String)        // classifies + de-dupes consecutive
    func search(_ q: String) -> [ClipItem]
    func togglePin(_ id: UUID)
}
```

## Feature flags

Paid features, in-app updates and force-update are built but **gated OFF** via
Remote Config (`RemoteConfigKit`), flipped on later with no app update.
`GoogleService-Info.plist` is **not** committed.

## License

Shell: MIT (see `LICENSE`). Engine: proprietary.
