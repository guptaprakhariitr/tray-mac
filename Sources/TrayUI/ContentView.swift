import SwiftUI
import AppKit
import DesignSystem
import DrawerEngine
import UniformTypeIdentifiers

public struct ContentView: View {
    @EnvironmentObject var vm: TrayViewModel

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch vm.pane {
            case .clipboard: clipboardPane
            case .shelf:     shelfPane
            case .notes:     notesPane
            }
        }
        .frame(minWidth: 360, idealWidth: 380, minHeight: 520, idealHeight: 640)
        .background(DS.Color.bg)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DS.Space.sm) {
            HStack {
                Text("Tray").font(DS.Font.display)
                Spacer()
                Button { vm.captureClipboard() } label: {
                    Label("Capture", systemImage: "square.and.arrow.down.on.square")
                }
            }
            Picker("", selection: $vm.pane) {
                ForEach(TrayPane.allCases, id: \.self) { p in
                    Label(p.title, systemImage: p.systemImage).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(DS.Space.md)
    }

    // MARK: Clipboard

    private var clipboardPane: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(DS.Color.tertiaryLabel)
                TextField("Search history", text: $vm.query)
                    .textFieldStyle(.plain)
            }
            .padding(DS.Space.sm)
            .background(DS.Color.bgElevated, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.sm)

            List {
                ForEach(vm.visibleClips) { clip in
                    clipRow(clip)
                        .contentShape(Rectangle())
                        .onTapGesture { vm.copyToPasteboard(clip) }
                }
            }
            .listStyle(.inset)
        }
    }

    private func clipRow(_ clip: ClipItem) -> some View {
        HStack(spacing: DS.Space.sm) {
            kindIcon(clip)
            Text(clip.text)
                .font(DS.Font.body)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button { vm.togglePin(clip.id) } label: {
                Image(systemName: clip.pinned ? "pin.fill" : "pin")
                    .foregroundStyle(clip.pinned ? DS.Color.accent : DS.Color.tertiaryLabel)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func kindIcon(_ clip: ClipItem) -> some View {
        switch clip.kind {
        case .color:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: clip.text) ?? DS.Color.separator)
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(DS.Color.separator, lineWidth: 0.5))
        case .url:
            Image(systemName: "link").foregroundStyle(DS.Color.accent).frame(width: 18)
        case .image:
            Image(systemName: "photo").foregroundStyle(DS.Color.secondaryLabel).frame(width: 18)
        case .text:
            Image(systemName: "text.alignleft").foregroundStyle(DS.Color.secondaryLabel).frame(width: 18)
        }
    }

    // MARK: Shelf

    private var shelfPane: some View {
        ScrollView {
            if vm.files.isEmpty {
                VStack(spacing: DS.Space.sm) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 44))
                        .foregroundStyle(DS.Color.tertiaryLabel)
                    Text("Drop files here").font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
                }
                .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: DS.Space.md)], spacing: DS.Space.md) {
                    ForEach(vm.files) { file in fileTile(file) }
                }
                .padding(DS.Space.md)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { vm.loadDrop($0) }
    }

    private func fileTile(_ file: ShelfFile) -> some View {
        VStack(spacing: DS.Space.xs) {
            Image(systemName: file.systemImage).font(.system(size: 34)).foregroundStyle(DS.Color.accent)
            Text(file.name).font(DS.Font.caption).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(width: 96, height: 96)
        .padding(DS.Space.sm)
        .background(DS.Color.bgElevated, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(alignment: .topTrailing) {
            Button { vm.removeFile(file.id) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Color.tertiaryLabel)
            }
            .buttonStyle(.plain).padding(4)
        }
    }

    // MARK: Notes

    private var notesPane: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            TextEditor(text: $vm.note)
                .font(DS.Font.mono)
                .scrollContentBackground(.hidden)
                .padding(DS.Space.sm)
                .background(DS.Color.bgElevated, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .onChange(of: vm.note) { _, _ in vm.noteChanged() }
            if let result = vm.noteResult {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "equal.circle.fill").foregroundStyle(DS.Color.accent)
                    Text(result).font(DS.Font.headline).foregroundStyle(DS.Color.accent)
                }
            }
        }
        .padding(DS.Space.md)
    }
}

// MARK: - Hex color helper

extension Color {
    /// Parse `#RGB` or `#RRGGBB` into a Color; nil if malformed.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((v & 0xFF0000) >> 16) / 255,
            green: Double((v & 0x00FF00) >> 8) / 255,
            blue: Double(v & 0x0000FF) / 255
        )
    }
}
