import Foundation
import AppKit
import SwiftUI
import DrawerEngine
import TrayUI
import ScreenshotKit

/// Consistent Plainware App Store marketing hero (typographic; ImageRenderer-safe —
/// only gradients/shapes/Text, no blur/shadow). Shared layout across all 5 apps;
/// each app supplies its own name, tagline, benefit bullets and accent color.
struct HeroShot: View {
    let appName: String
    let tagline: String
    let bullets: [String]
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.035)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.30), .clear],
                           center: .topTrailing, startRadius: 40, endRadius: 1300)
            VStack(alignment: .leading, spacing: 0) {
                Text("PLAINWARE")
                    .font(.system(size: 26, weight: .bold)).tracking(8)
                    .foregroundStyle(accent)
                Spacer().frame(height: 40)
                Text(appName)
                    .font(.system(size: 150, weight: .heavy)).foregroundStyle(.white)
                Spacer().frame(height: 24)
                Text(tagline)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 48)
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(bullets, id: \.self) { b in
                        HStack(spacing: 20) {
                            ZStack {
                                Circle().fill(accent).frame(width: 38, height: 38)
                                Text("✓").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                            }
                            Text(b).font(.system(size: 36)).foregroundStyle(.white.opacity(0.88))
                        }
                    }
                }
                Spacer()
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 60, height: 8)
                    Text("100% on-device  ·  Free & open source  ·  macOS")
                        .font(.system(size: 28, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(150)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ✓ \(msg)") } else { print("  ✗ \(msg)"); failures += 1 }
}
func section(_ s: String) { print("\n▸ \(s)") }

section("classify")
check(classify("https://example.com") == .url, "detects https URL")
check(classify("www.apple.com") == .url, "detects www URL")
check(classify("#FF8800") == .color, "detects 6-digit hex color")
check(classify("#abc") == .color, "detects 3-digit hex color")
check(classify("just text") == .text, "plain text falls through")
check(classify("#GG0000") == .text, "rejects non-hex as text")

section("evaluateInline")
check(evaluateInline("12*3") == "36", "12*3 -> 36")
check(evaluateInline("（2+2)/4") == "1", "full-width paren expr -> 1")
check(evaluateInline("(2+2)/4") == "1", "ascii paren expr -> 1")
check(evaluateInline("hello") == nil, "non-expression -> nil")
check(evaluateInline("42") == nil, "bare number (no operator) -> nil")
check(evaluateInline("10 / 4") == "2.5", "non-integer result -> 2.5")

section("ClipboardStore add + search")
MainActor.assumeIsolated {
    let store = ClipboardStore()
    store.add("https://plainware.com")
    store.add("#FF8800")
    store.add("the quick brown fox")
    store.add("the quick brown fox") // consecutive dup ignored
    check(store.items.count == 3, "de-dupes consecutive identical adds (\(store.items.count) items)")
    check(store.items.first?.kind == .text, "newest item is on top")
    let hits = store.search("quick")
    check(hits.count == 1 && hits.first?.text == "the quick brown fox", "search returns matching clip")
    check(store.search("FF88").first?.kind == .color, "search finds the color clip")

    if let id = store.items.first(where: { $0.kind == .color })?.id {
        store.togglePin(id)
        check(store.items.first(where: { $0.id == id })?.pinned == true, "togglePin flips pinned")
    } else {
        check(false, "found a color clip to pin")
    }
}

section("ClipboardStore exact-text + delete")
MainActor.assumeIsolated {
    let store = ClipboardStore()
    // The clipping bug: multi-line / padded text must be preserved verbatim.
    let exact = "  line one\nline two\n"
    store.add(exact)
    check(store.items.first?.text == exact, "preserves exact text incl. newlines + whitespace")

    store.add("alpha"); store.add("beta")
    if let id = store.items.first(where: { $0.text == "alpha" })?.id {
        store.remove(id)
        check(!store.items.contains { $0.text == "alpha" }, "remove(id) deletes the clip")
    } else { check(false, "found 'alpha' to remove") }

    // Pin newest, clear the rest.
    if let id = store.items.first?.id {
        store.togglePin(id)
        store.clearUnpinned()
        check(store.items.count == 1 && store.items.first?.pinned == true,
              "clearUnpinned keeps only pinned (\(store.items.count) left)")
    } else { check(false, "had an item to pin") }
}

section("Passcode PBKDF2")
do {
    let salt = Data((0..<16).map { UInt8($0) })
    let a = PasscodeStore.pbkdf2("hunter2", salt: salt, rounds: 10_000)
    let b = PasscodeStore.pbkdf2("hunter2", salt: salt, rounds: 10_000)
    let c = PasscodeStore.pbkdf2("hunter3", salt: salt, rounds: 10_000)
    let d = PasscodeStore.pbkdf2("hunter2", salt: Data(repeating: 9, count: 16), rounds: 10_000)
    check(a.count == 32, "derives a 32-byte key")
    check(a == b, "same passcode + salt is deterministic")
    check(a != c, "different passcode → different key")
    check(a != d, "different salt → different key")
}

// MARK: Render real screenshots off-screen (no screen-recording permission)
section("Screenshots")
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./screenshots")

MainActor.assumeIsolated {
    let scene = ScreenshotScene()
    do {
        let url = outDir.appendingPathComponent("01-app-ui.png")
        try ViewSnapshotter.renderStoreShot(scene, size: .s1440x900, to: url)
        check(FileManager.default.fileExists(atPath: url.path), "rendered drawer UI → \(url.lastPathComponent)")
    } catch { check(false, "drawer UI render: \(error)") }

    let hero = HeroShot(
        appName: "Tray",
        tagline: "Everything you reach for,\none edge drawer.",
        bullets: ["Searchable clipboard history",
                  "Drag-in / drag-out file shelf",
                  "Quick notes with inline math"],
        accent: Color(red: 0.16, green: 0.78, blue: 0.62)
    )
    do {
        let url = outDir.appendingPathComponent("02-marketing.png")
        try ViewSnapshotter.renderStoreShot(hero, size: .s2560x1600, to: url)
        check(FileManager.default.fileExists(atPath: url.path), "rendered marketing hero → \(url.lastPathComponent)")
    } catch { check(false, "marketing render: \(error)") }
}

print("\n" + (failures == 0 ? "✅ ALL CHECKS PASSED" : "❌ \(failures) FAILED"))
exit(failures == 0 ? 0 : 1)
