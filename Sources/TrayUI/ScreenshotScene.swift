import SwiftUI
import AppKit
import DesignSystem
import DrawerEngine

/// An `ImageRenderer`-safe reproduction of the TrayShelf edge-drawer for App Store
/// screenshots. The live app uses List/ScrollView/segmented Picker which
/// ImageRenderer can't snapshot, so this is built from plain primitives only
/// (VStack/HStack/ZStack/Text/Image/Shape/RoundedRectangle/Capsule/Circle/
/// Divider/LinearGradient).
public struct ScreenshotScene: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 60) {
                headline
                drawer.frame(width: 380)
            }
            .padding(80)
        }
    }

    // MARK: Marketing headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            Text("TrayShelf")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Clipboard history, a file shelf and\nquick notes — one edge drawer.")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: DS.Space.md) {
                bullet("doc.on.clipboard", "Searchable clipboard history")
                bullet("tray.full", "Drag-and-drop file shelf")
                bullet("note.text", "Notes with inline math")
            }
            .padding(.top, DS.Space.sm)
        }
        .frame(width: 520, alignment: .leading)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(Color.accentColor)
                .frame(width: 30)
            Text(text).font(.system(size: 20)).foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: Drawer mock

    private var drawer: some View {
        VStack(spacing: 0) {
            drawerHeader
            Divider()
            clipboardPane
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 18)
    }

    private var drawerHeader: some View {
        VStack(spacing: DS.Space.sm) {
            HStack {
                Text("TrayShelf").font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 18)).foregroundStyle(.secondary)
            }
            segmented
        }
        .padding(DS.Space.md)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segment("doc.on.clipboard", "Clipboard", selected: true)
            segment("tray.full", "Shelf", selected: false)
            segment("note.text", "Notes", selected: false)
        }
        .padding(3)
        .background(Capsule().fill(Color.gray.opacity(0.18)))
    }

    private func segment(_ icon: String, _ title: String, selected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 12))
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .foregroundStyle(selected ? Color.white : Color.secondary)
        .background(Capsule().fill(selected ? Color.accentColor : Color.clear))
    }

    // MARK: Clipboard pane (populated with realistic sample data)

    private var clipboardPane: some View {
        VStack(spacing: DS.Space.sm) {
            searchBar
            VStack(spacing: 2) {
                clipRow(icon: .url, "https://plainware.com/tray", pinned: true)
                clipRow(icon: .color, "#FF8800", pinned: false)
                clipRow(icon: .text, "the quick brown fox", pinned: false)
                clipRow(icon: .text, "git rebase -i HEAD~3", pinned: false)
                clipRow(icon: .url, "www.apple.com", pinned: false)
            }
            shelfStrip
            notePreview
        }
        .padding(DS.Space.md)
    }

    private var searchBar: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            Text("Search history").font(.system(size: 13)).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(DS.Space.sm)
        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.gray.opacity(0.14)))
    }

    private func clipRow(icon: ClipKind, _ text: String, pinned: Bool) -> some View {
        HStack(spacing: DS.Space.sm) {
            clipIcon(icon)
            Text(text).font(.system(size: 13)).lineLimit(1)
            Spacer()
            Image(systemName: pinned ? "pin.fill" : "pin")
                .font(.system(size: 12))
                .foregroundStyle(pinned ? Color.accentColor : Color.secondary.opacity(0.5))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DS.Space.sm)
    }

    @ViewBuilder
    private func clipIcon(_ kind: ClipKind) -> some View {
        switch kind {
        case .color:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 1.0, green: 0.53, blue: 0.0)) // #FF8800
                .frame(width: 18, height: 18)
        case .url:
            Image(systemName: "link").foregroundStyle(Color.accentColor).frame(width: 18)
        case .image:
            Image(systemName: "photo").foregroundStyle(.secondary).frame(width: 18)
        case .text:
            Image(systemName: "text.alignleft").foregroundStyle(.secondary).frame(width: 18)
        }
    }

    // MARK: Mini shelf + note previews

    private var shelfStrip: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("SHELF").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            HStack(spacing: DS.Space.sm) {
                fileTile("photo", "shot.png")
                fileTile("doc.richtext", "spec.pdf")
                fileTile("doc.zipper", "build.zip")
            }
        }
        .padding(.top, DS.Space.xs)
    }

    private func fileTile(_ icon: String, _ name: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(Color.accentColor)
            Text(name).font(.system(size: 10)).lineLimit(1)
        }
        .frame(width: 70, height: 64)
        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.gray.opacity(0.14)))
    }

    private var notePreview: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("NOTES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("budget split\n12 * 3")
                    .font(.system(size: 12, design: .monospaced))
                HStack(spacing: 4) {
                    Image(systemName: "equal.circle.fill").foregroundStyle(Color.accentColor)
                    Text("12 * 3 = 36").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(DS.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.gray.opacity(0.14)))
        }
        .padding(.top, DS.Space.xs)
    }
}
