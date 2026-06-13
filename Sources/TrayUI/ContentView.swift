import SwiftUI
import AppKit
import DesignSystem
import DrawerEngine
import UniformTypeIdentifiers

public struct ContentView: View {
    @EnvironmentObject var vm: TrayViewModel
    @State private var hoveredClip: UUID?
    @State private var showPasscodeSheet = false

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
        .sheet(isPresented: $showPasscodeSheet) {
            PasscodeSheet().environmentObject(vm)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Text("Tray").font(DS.Font.display)
                Spacer()

                // Auto-capture toggle
                Toggle(isOn: $vm.autoCapture) {
                    Label("Auto", systemImage: vm.autoCapture ? "bolt.fill" : "bolt.slash")
                }
                .toggleStyle(.button)
                .help(vm.autoCapture
                      ? "Auto-capture is ON — everything you copy is saved automatically"
                      : "Auto-capture is OFF — use Capture to save the clipboard manually")

                // Private-mode lock control
                privacyControl

                Button { vm.captureClipboard() } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
                .help("Capture the current clipboard contents into history")
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

    @ViewBuilder
    private var privacyControl: some View {
        if vm.hasPasscode {
            Button {
                if vm.isLocked { showPasscodeSheet = true } else { vm.lock() }
            } label: {
                Image(systemName: vm.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(vm.isLocked ? DS.Color.accent : DS.Color.secondaryLabel)
            }
            .help(vm.isLocked ? "Locked — enter passcode to reveal clips" : "Lock private mode")
        } else {
            Menu {
                Button("Set Passcode…") { showPasscodeSheet = true }
            } label: {
                Image(systemName: "lock.slash")
            }
            .menuIndicator(.hidden)
            .help("Private mode — set a passcode to mask clipboard contents")
        }
    }

    // MARK: Clipboard

    private var clipboardPane: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(DS.Color.tertiaryLabel)
                TextField("Search history", text: $vm.query)
                    .textFieldStyle(.plain)
                if !vm.visibleClips.isEmpty {
                    Menu {
                        Button("Clear unpinned", role: .destructive) { vm.clearUnpinned() }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(DS.Color.tertiaryLabel)
                    }
                    .menuIndicator(.hidden)
                    .frame(width: 22)
                }
            }
            .padding(DS.Space.sm)
            .background(DS.Color.bgElevated, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.sm)

            if vm.isLocked { lockedBanner }

            if vm.visibleClips.isEmpty {
                emptyClipboard
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Space.xs) {
                        ForEach(vm.visibleClips) { clip in
                            clipRow(clip)
                        }
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, DS.Space.md)
                }
            }
        }
    }

    private var lockedBanner: some View {
        Button { showPasscodeSheet = true } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "lock.fill")
                Text("Private mode — tap to enter your passcode and reveal clips")
                    .font(DS.Font.caption)
                Spacer()
            }
            .foregroundStyle(DS.Color.accent)
            .padding(DS.Space.sm)
            .frame(maxWidth: .infinity)
            .background(DS.Color.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Space.md)
        .padding(.bottom, DS.Space.sm)
    }

    private var emptyClipboard: some View {
        VStack(spacing: DS.Space.sm) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 40))
                .foregroundStyle(DS.Color.tertiaryLabel)
            Text(vm.query.isEmpty ? "Nothing copied yet" : "No matches")
                .font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
            if vm.query.isEmpty {
                Text(vm.autoCapture ? "Copy anything and it shows up here." : "Turn on Auto, or press Capture.")
                    .font(DS.Font.caption).foregroundStyle(DS.Color.tertiaryLabel)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }

    // MARK: Clip row

    private func clipRow(_ clip: ClipItem) -> some View {
        let hovered = hoveredClip == clip.id
        return HStack(alignment: .top, spacing: DS.Space.sm) {
            kindIcon(clip)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.displayText(for: clip))
                    .font(clip.kind == .url || clip.kind == .color ? DS.Font.mono : DS.Font.body)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .foregroundStyle(DS.Color.label)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DS.Space.xs) {
                    Text(clip.kind.label).font(DS.Font.caption)
                        .foregroundStyle(DS.Color.tertiaryLabel)
                    Text("·").foregroundStyle(DS.Color.tertiaryLabel)
                    Text(Self.relative(clip.date)).font(DS.Font.caption)
                        .foregroundStyle(DS.Color.tertiaryLabel)
                    if !vm.isLocked, clip.kind == .text {
                        Text("·").foregroundStyle(DS.Color.tertiaryLabel)
                        Text("\(clip.text.count) chars").font(DS.Font.caption)
                            .foregroundStyle(DS.Color.tertiaryLabel)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                if hovered && !vm.isLocked {
                    iconButton("trash", help: "Delete this clip") { vm.remove(clip.id) }
                }
                iconButton(clip.pinned ? "pin.fill" : "pin",
                           tint: clip.pinned ? DS.Color.accent : DS.Color.tertiaryLabel,
                           help: clip.pinned ? "Unpin" : "Pin to top") { vm.togglePin(clip.id) }
            }
        }
        .padding(DS.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(hovered ? DS.Color.bgElevated : Color.clear)
        )
        .overlay(alignment: .leading) {
            if clip.pinned {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Color.accent)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.copyToPasteboard(clip) }
        .onHover { hoveredClip = $0 ? clip.id : (hoveredClip == clip.id ? nil : hoveredClip) }
        .help(vm.isLocked ? "Locked" : "Click to copy back to the clipboard")
    }

    private func iconButton(_ name: String, tint: Color = DS.Color.tertiaryLabel,
                            help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).foregroundStyle(tint).frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private func kindIcon(_ clip: ClipItem) -> some View {
        switch clip.kind {
        case .color:
            RoundedRectangle(cornerRadius: 4)
                .fill(vm.isLocked ? DS.Color.separator : (Color(hex: clip.text) ?? DS.Color.separator))
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

    private static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
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
            .help("Remove from shelf")
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

// MARK: - Clip kind label

extension ClipKind {
    var label: String {
        switch self {
        case .text:  return "Text"
        case .url:   return "Link"
        case .color: return "Color"
        case .image: return "Image"
        }
    }
}

// MARK: - Passcode sheet (set / unlock / remove)

struct PasscodeSheet: View {
    @EnvironmentObject var vm: TrayViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Label(title, systemImage: "lock.shield")
                .font(DS.Font.headline)

            Text(subtitle)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            SecureField(vm.hasPasscode && vm.isLocked ? "Passcode" : "New passcode (min 4)", text: $code)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            if !vm.hasPasscode {
                SecureField("Confirm passcode", text: $confirm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
            }

            if let error {
                Text(error).font(DS.Font.caption).foregroundStyle(.red)
            }

            HStack {
                if vm.hasPasscode && !vm.isLocked {
                    Button("Remove Passcode", role: .destructive) {
                        if vm.removePasscode(code) { dismiss() }
                        else { error = "Wrong passcode." }
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(primaryTitle, action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(code.isEmpty)
            }
        }
        .padding(DS.Space.lg)
        .frame(width: 360)
    }

    private var title: String {
        if vm.hasPasscode && vm.isLocked { return "Enter Passcode" }
        if vm.hasPasscode { return "Private Mode" }
        return "Set a Passcode"
    }

    private var subtitle: String {
        if vm.hasPasscode && vm.isLocked {
            return "Your clipboard history is masked. Enter your passcode to reveal it."
        }
        if vm.hasPasscode {
            return "Private mode is set up. You can lock it from the header, or remove the passcode below."
        }
        return "Private mode masks every clip to a couple of characters until you enter this passcode. Your history is also encrypted on disk."
    }

    private var primaryTitle: String {
        if vm.hasPasscode && vm.isLocked { return "Unlock" }
        if vm.hasPasscode { return "Done" }
        return "Set Passcode"
    }

    private func submit() {
        error = nil
        if vm.hasPasscode {
            if vm.isLocked {
                if vm.unlock(code) { dismiss() } else { error = "Wrong passcode." }
            } else {
                dismiss()
            }
        } else {
            guard code.count >= 4 else { error = "Use at least 4 characters."; return }
            guard code == confirm else { error = "Passcodes don't match."; return }
            vm.setPasscode(code)
            dismiss()
        }
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
