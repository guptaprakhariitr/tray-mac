import Foundation
import AppKit
import SwiftUI
import DrawerEngine
import TrayUI
import ScreenshotKit

let trayAccent = Color(red: 0.16, green: 0.78, blue: 0.62)

/// TrayShelf product visual — the real edge drawer reproduced for store shots:
/// a vertical drawer panel with a search field, three tabs (Clipboard / Shelf /
/// Notes) and a content pane that switches by `highlight`. Fills width `w`; all
/// metrics scale off it. ImageRenderer-safe (shapes / Text only, no blur/shadow).
struct TrayCanvas: View {
    var w: CGFloat
    var highlight: Highlight = .clipboard
    enum Highlight { case clipboard, shelf, notes }
    private func s(_ v: CGFloat) -> CGFloat { v * w / 1120 }

    var body: some View {
        ZStack {
            Color(white: 0.13)
            // Centered drawer panel, like the edge drawer slid open.
            drawer
                .frame(width: s(440))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: w, height: w * 600 / 1120)
        .clipped()
    }

    private var drawer: some View {
        VStack(spacing: s(16)) {
            // Title row
            HStack {
                Text("TrayShelf").font(.system(size: s(22), weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: s(15))).foregroundStyle(trayAccent)
            }
            searchField
            tabs
            content
            Spacer(minLength: 0)
        }
        .padding(s(20))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: s(18), style: .continuous)
            .fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: s(18), style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: s(1)))
        .padding(.vertical, s(30))
    }

    private var searchField: some View {
        HStack(spacing: s(10)) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: s(15))).foregroundStyle(Color.white.opacity(0.45))
            Text("Search").font(.system(size: s(15)))
                .foregroundStyle(Color.white.opacity(0.45))
            Spacer()
        }
        .padding(.horizontal, s(14)).padding(.vertical, s(11))
        .background(RoundedRectangle(cornerRadius: s(10)).fill(Color(white: 0.10)))
    }

    private var tabs: some View {
        HStack(spacing: s(4)) {
            tab("doc.on.clipboard", "Clipboard", on: highlight == .clipboard)
            tab("tray.full", "Shelf", on: highlight == .shelf)
            tab("note.text", "Notes", on: highlight == .notes)
        }
        .padding(s(4))
        .background(Capsule().fill(Color(white: 0.10)))
    }

    private func tab(_ icon: String, _ title: String, on: Bool) -> some View {
        HStack(spacing: s(6)) {
            Image(systemName: icon).font(.system(size: s(13)))
            Text(title).font(.system(size: s(14), weight: .semibold))
        }
        .foregroundStyle(on ? Color.white : Color.white.opacity(0.55))
        .padding(.vertical, s(8))
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(on ? trayAccent : Color.clear))
    }

    @ViewBuilder private var content: some View {
        switch highlight {
        case .clipboard: clipboardList
        case .shelf: shelfTiles
        case .notes: notesPane
        }
    }

    // MARK: Clipboard — history list with leading glyph chips
    private var clipboardList: some View {
        VStack(spacing: s(8)) {
            clipRow(.url, "https://plainware.com/tray", pinned: true)
            clipRow(.code, "git rebase -i HEAD~3")
            clipRow(.color, "#FF8800")
            clipRow(.text, "the quick brown fox")
        }
    }

    enum Chip { case url, code, color, text }

    private func clipRow(_ chip: Chip, _ text: String, pinned: Bool = false) -> some View {
        HStack(spacing: s(12)) {
            chipGlyph(chip)
            Text(text)
                .font(.system(size: s(15), design: chip == .code ? .monospaced : .default))
                .foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: pinned ? "pin.fill" : "pin")
                .font(.system(size: s(13)))
                .foregroundStyle(pinned ? trayAccent : Color.white.opacity(0.3))
        }
        .padding(.horizontal, s(12)).padding(.vertical, s(11))
        .background(RoundedRectangle(cornerRadius: s(10)).fill(Color(white: 0.10)))
    }

    @ViewBuilder private func chipGlyph(_ chip: Chip) -> some View {
        let side = s(26)
        switch chip {
        case .color:
            RoundedRectangle(cornerRadius: s(6))
                .fill(Color(red: 1.0, green: 0.53, blue: 0.0))
                .frame(width: side, height: side)
        default:
            ZStack {
                RoundedRectangle(cornerRadius: s(6)).fill(trayAccent.opacity(0.18))
                Image(systemName: chip == .url ? "link"
                                : chip == .code ? "chevron.left.forwardslash.chevron.right"
                                : "text.alignleft")
                    .font(.system(size: s(13), weight: .semibold)).foregroundStyle(trayAccent)
            }
            .frame(width: side, height: side)
        }
    }

    // MARK: Shelf — dragged file tiles
    private var shelfTiles: some View {
        VStack(spacing: s(14)) {
            HStack(spacing: s(14)) {
                fileTile("photo", "shot.png")
                fileTile("doc.richtext", "spec.pdf")
            }
            HStack(spacing: s(14)) {
                fileTile("doc.zipper", "build.zip")
                fileTile("plus", "Drop files", dashed: true)
            }
        }
    }

    private func fileTile(_ icon: String, _ name: String, dashed: Bool = false) -> some View {
        VStack(spacing: s(10)) {
            Image(systemName: icon)
                .font(.system(size: s(30)))
                .foregroundStyle(dashed ? Color.white.opacity(0.4) : trayAccent)
            Text(name).font(.system(size: s(13)))
                .foregroundStyle(dashed ? Color.white.opacity(0.4) : .white).lineLimit(1)
        }
        .frame(maxWidth: .infinity).frame(height: s(110))
        .background(
            RoundedRectangle(cornerRadius: s(12))
                .fill(Color(white: 0.10))
                .overlay(
                    Group {
                        if dashed {
                            RoundedRectangle(cornerRadius: s(12))
                                .strokeBorder(Color.white.opacity(0.25),
                                              style: StrokeStyle(lineWidth: s(2), dash: [s(7), s(5)]))
                        }
                    }
                )
        )
    }

    // MARK: Notes — pane with an inline calculation
    private var notesPane: some View {
        VStack(alignment: .leading, spacing: s(12)) {
            Text("Budget split")
                .font(.system(size: s(17), weight: .semibold)).foregroundStyle(.white)
            Text("rent 1200 / 3\ngroceries this week\n12 * 3")
                .font(.system(size: s(15), design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineSpacing(s(6))
            HStack(spacing: s(8)) {
                Image(systemName: "equal.circle.fill")
                    .font(.system(size: s(18))).foregroundStyle(trayAccent)
                Text("12 * 3 = 36")
                    .font(.system(size: s(18), weight: .bold, design: .monospaced))
                    .foregroundStyle(trayAccent)
            }
            .padding(.horizontal, s(12)).padding(.vertical, s(10))
            .background(RoundedRectangle(cornerRadius: s(10)).fill(trayAccent.opacity(0.14)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(s(16))
        .background(RoundedRectangle(cornerRadius: s(12)).fill(Color(white: 0.10)))
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

// MARK: Render App Store screenshots off-screen (no screen-recording permission)
section("Screenshots")
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./screenshots")
let theme = StoreTheme.dark(trayAccent)
let shotSize = ViewSnapshotter.StoreSize.s2560x1600.pixels
let cw = shotSize.width / 1440 * 1120   // content width inside the window frame

MainActor.assumeIsolated {
    @MainActor func shot<V: View>(_ name: String, _ view: V) {
        do {
            let url = outDir.appendingPathComponent(name)
            try ViewSnapshotter.renderPNG(view, size: shotSize, scale: 1.0, to: url)
            check(FileManager.default.fileExists(atPath: url.path), "rendered \(name)")
        } catch { check(false, "\(name): \(error)") }
    }
    shot("01-hero.png", FeatureShot(
        theme: theme, tag: "Plainware",
        headline: "Clipboard, shelf\n& notes in one drawer.",
        subhead: "Everything you copy, stash and jot — in one private edge drawer, encrypted on your Mac.",
        windowTitle: "TrayShelf", size: shotSize) { TrayCanvas(w: cw, highlight: .clipboard) })
    shot("02-shelf.png", FeatureShot(
        theme: theme,
        headline: "A shelf for your files",
        subhead: "Drag files in to stash them, then drag them back out wherever you need.",
        windowTitle: "TrayShelf", size: shotSize) { TrayCanvas(w: cw, highlight: .shelf) })
    shot("03-notes.png", FeatureShot(
        theme: theme,
        headline: "Notes that do math",
        subhead: "Jot quick notes — type 12 * 3 and it solves the last line inline.",
        windowTitle: "TrayShelf", size: shotSize) { TrayCanvas(w: cw, highlight: .notes) })
}

print("\n" + (failures == 0 ? "✅ ALL CHECKS PASSED" : "❌ \(failures) FAILED"))
exit(failures == 0 ? 0 : 1)
