import SwiftUI
import AppKit
import DrawerEngine
import LogKit
import UniformTypeIdentifiers

/// A file dropped onto the shelf.
public struct ShelfFile: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var url: URL?
    public var systemImage: String
    public init(id: UUID = UUID(), name: String, url: URL? = nil, systemImage: String) {
        self.id = id; self.name = name; self.url = url; self.systemImage = systemImage
    }
}

/// Which pane of the drawer is showing.
public enum TrayPane: String, CaseIterable, Sendable {
    case clipboard, shelf, notes
    public var title: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .shelf:     return "Shelf"
        case .notes:     return "Notes"
        }
    }
    public var systemImage: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .shelf:     return "tray.full"
        case .notes:     return "note.text"
        }
    }
}

@MainActor
public final class TrayViewModel: ObservableObject {
    @Published public var pane: TrayPane = .clipboard
    @Published public var query: String = ""
    @Published public var files: [ShelfFile] = []
    @Published public var note: String = ""

    public let clips = ClipboardStore()

    public init() {}

    /// Items currently shown in the clipboard pane (filtered by `query`).
    public var visibleClips: [ClipItem] {
        clips.search(query)
    }

    /// Capture the current text contents of the general pasteboard.
    public func captureClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) {
            add(s)
        } else {
            AppLog.warn("clipboard capture found no text", category: "clipboard")
        }
    }

    public func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        clips.add(trimmed)
        AppLog.info("clipboard item captured (kind=\(classify(trimmed).rawValue))", category: "clipboard")
    }
    public func togglePin(_ id: UUID) { clips.togglePin(id) }

    /// Copy a clip's text back onto the pasteboard. The user presses Cmd-V
    /// themselves — we deliberately do NOT synthesize a paste keystroke.
    public func copyToPasteboard(_ item: ClipItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }

    // MARK: Shelf

    @discardableResult
    public func loadDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url else { return }
                Task { @MainActor in self?.addFile(url) }
            }
        }
        return handled
    }

    public func addFile(_ url: URL) {
        files.insert(ShelfFile(name: url.lastPathComponent, url: url, systemImage: Self.icon(for: url)), at: 0)
        AppLog.info("file added to shelf: \(url.lastPathComponent)", category: "shelf")
    }

    public func removeFile(_ id: UUID) {
        files.removeAll { $0.id == id }
    }

    static func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "tiff": return "photo"
        case "pdf":                                        return "doc.richtext"
        case "zip", "tar", "gz":                           return "doc.zipper"
        case "mov", "mp4", "m4v":                          return "film"
        case "mp3", "wav", "aac", "m4a":                   return "music.note"
        case "txt", "md", "rtf":                           return "doc.text"
        case "":                                           return "folder"
        default:                                           return "doc"
        }
    }

    /// The live inline-calc result for the last non-empty note line, if any.
    public var noteResult: String? {
        guard let line = note
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return nil }
        return evaluateInline(line)
    }

    /// Last inline-calc result we logged, to avoid logging on every keystroke.
    private var lastLoggedNoteResult: String?

    /// Recompute the inline-calc result and log it once when it changes.
    /// Call from the notes view's `onChange(of:)`.
    public func noteChanged() {
        let result = noteResult
        guard result != lastLoggedNoteResult else { return }
        lastLoggedNoteResult = result
        if let result {
            AppLog.info("note inline-calc evaluated → \(result)", category: "notes")
        }
    }
}
