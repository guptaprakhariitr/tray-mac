import XCTest
import AppKit
import SwiftUI
@testable import TrayUI
@testable import DrawerEngine

/// Button-flow tests: every interactive control in ContentView is mapped to the
/// exact view-model handler it invokes, and asserted input -> output here. The
/// VM is always constructed with an isolated Keychain `service`, in-memory
/// history (`persistence: nil`) and `monitorClipboard: false` so nothing touches
/// the real container, Keychain or live pasteboard timer.
@MainActor
final class DrawerUITests: XCTestCase {

    private func makeVM() -> TrayViewModel {
        TrayViewModel(service: "com.plainware.tray.test.\(UUID().uuidString)",
                      persistence: nil, monitorClipboard: false)
    }

    // MARK: Header — auto-capture toggle (Toggle bound to vm.autoCapture)

    func testAutoCaptureTogglePersistsAndStays() {
        let vm = makeVM()
        XCTAssertFalse(vm.autoCapture)          // monitorClipboard:false -> starts off
        vm.autoCapture = true                    // toggle on (didSet persists + starts monitor)
        XCTAssertTrue(vm.autoCapture)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "tray.autoCapture"))
        vm.autoCapture = false
        XCTAssertFalse(vm.autoCapture)
    }

    // MARK: Header — Capture button (vm.captureClipboard)

    func testCaptureClipboardPullsCurrentPasteboardText() {
        let vm = makeVM()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("captured-value", forType: .string)
        vm.captureClipboard()
        XCTAssertEqual(vm.clips.items.first?.text, "captured-value")
    }

    // MARK: Header — pane Picker (segmented control bound to vm.pane)

    func testPaneSelection() {
        let vm = makeVM()
        XCTAssertEqual(vm.pane, .clipboard)
        vm.pane = .notes
        XCTAssertEqual(vm.pane, .notes)
        XCTAssertEqual(TrayPane.allCases.count, 3)
        XCTAssertEqual(TrayPane.shelf.title, "Shelf")
        XCTAssertEqual(TrayPane.clipboard.systemImage, "doc.on.clipboard")
    }

    // MARK: Search field (vm.query -> vm.visibleClips)

    func testSearchFiltersVisibleClips() {
        let vm = makeVM()
        vm.add("apple pie")
        vm.add("banana split")
        vm.query = "APPLE"
        XCTAssertEqual(vm.visibleClips.map(\.text), ["apple pie"])
        vm.query = ""
        XCTAssertEqual(vm.visibleClips.count, 2)
    }

    // MARK: Clip row — copy icon (vm.copyToPasteboard) writes EXACT pasteboard

    func testCopyToPasteboardWritesExactString() {
        let vm = makeVM()
        let item = ClipItem(kind: .text, text: "verbatim\n  indented")
        vm.copyToPasteboard(item)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "verbatim\n  indented")
    }

    func testCopyToPasteboardBlockedWhileLocked() {
        let vm = makeVM()
        vm.setPasscode("1234")
        vm.lock()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("untouched", forType: .string)
        vm.copyToPasteboard(ClipItem(kind: .text, text: "secret"))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "untouched")
        vm.removePasscode("1234")
    }

    // MARK: Clip row — delete icon (vm.remove)

    func testRemoveClip() {
        let vm = makeVM()
        vm.add("a"); vm.add("b")
        let id = vm.clips.items[0].id
        vm.remove(id)
        XCTAssertEqual(vm.clips.items.map(\.text), ["a"])
    }

    // MARK: Clip row — pin icon (vm.togglePin)

    func testTogglePin() {
        let vm = makeVM()
        vm.add("x")
        let id = vm.clips.items[0].id
        vm.togglePin(id)
        XCTAssertTrue(vm.clips.items[0].pinned)
        vm.togglePin(id)
        XCTAssertFalse(vm.clips.items[0].pinned)
    }

    // MARK: Search menu — Clear unpinned (vm.clearUnpinned)

    func testClearUnpinnedKeepsPinned() {
        let vm = makeVM()
        vm.add("keep"); vm.add("drop")
        vm.togglePin(vm.clips.items.first { $0.text == "keep" }!.id)
        vm.clearUnpinned()
        XCTAssertEqual(vm.clips.items.map(\.text), ["keep"])
    }

    // MARK: Privacy control — Set passcode / Unlock / Lock / Remove

    func testPasscodeSetUnlockLockRemoveFlow() {
        let vm = makeVM()
        XCTAssertFalse(vm.hasPasscode)
        vm.setPasscode("4321")                  // PasscodeSheet "Set Passcode"
        XCTAssertTrue(vm.hasPasscode)
        XCTAssertFalse(vm.isLocked)             // setting unlocks current session
        vm.lock()                               // "Lock now"
        XCTAssertTrue(vm.isLocked)
        XCTAssertFalse(vm.unlock("0000"))       // wrong passcode -> stays locked
        XCTAssertTrue(vm.isLocked)
        XCTAssertTrue(vm.unlock("4321"))        // correct -> unlocks
        XCTAssertFalse(vm.isLocked)
        XCTAssertFalse(vm.removePasscode("0000")) // wrong -> no-op
        XCTAssertTrue(vm.hasPasscode)
        XCTAssertTrue(vm.removePasscode("4321"))
        XCTAssertFalse(vm.hasPasscode)
    }

    func testSetPasscodeRejectsTooShort() {
        let vm = makeVM()
        vm.setPasscode("12")                    // < 4 chars -> ignored
        XCTAssertFalse(vm.hasPasscode)
    }

    // MARK: Locked masking (vm.displayText)

    func testDisplayTextMaskedWhenLocked() {
        let vm = makeVM()
        let item = ClipItem(kind: .text, text: "supersecretvalue")
        XCTAssertEqual(vm.displayText(for: item), "supersecretvalue") // unlocked: verbatim
        vm.setPasscode("1234"); vm.lock()
        let masked = vm.displayText(for: item)
        XCTAssertTrue(masked.hasPrefix("su"))
        XCTAssertTrue(masked.contains("•"))
        XCTAssertFalse(masked.contains("secret"))
        vm.removePasscode("1234")
    }

    // MARK: Shelf — add / remove file + icon mapping

    func testAddAndRemoveFile() {
        let vm = makeVM()
        vm.addFile(URL(fileURLWithPath: "/tmp/photo.png"))
        vm.addFile(URL(fileURLWithPath: "/tmp/notes.txt"))
        XCTAssertEqual(vm.files.count, 2)
        XCTAssertEqual(vm.files.first?.name, "notes.txt")   // newest first
        XCTAssertEqual(vm.files.first?.systemImage, "doc.text")
        let id = vm.files[0].id
        vm.removeFile(id)
        XCTAssertEqual(vm.files.map(\.name), ["photo.png"])
    }

    func testShelfIconMapping() {
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/a.png")), "photo")
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/a.pdf")), "doc.richtext")
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/a.zip")), "doc.zipper")
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/a.mp4")), "film")
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/a.mp3")), "music.note")
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/folder")), "folder")
        XCTAssertEqual(TrayViewModel.icon(for: URL(fileURLWithPath: "/x/a.bin")), "doc")
    }

    // MARK: Notes — TextEditor binding + inline-calc result (vm.noteResult / noteChanged)

    func testNotesInlineCalc() {
        let vm = makeVM()
        vm.note = "shopping\n12 * 3"
        XCTAssertEqual(vm.noteResult, "36")     // evaluates last non-empty line
        vm.note = "just text"
        XCTAssertNil(vm.noteResult)
        vm.note = ""
        XCTAssertNil(vm.noteResult)
        vm.noteChanged()                        // logging path, no crash / no result
    }

    func testNoteResultUsesLastNonEmptyLine() {
        let vm = makeVM()
        vm.note = "2+2\n\n   "                   // trailing blank lines ignored
        XCTAssertEqual(vm.noteResult, "4")
    }

    // MARK: ClipDetailSheet open-URL helper path (vm.copyToPasteboard already covered)

    func testColorHexParsing() {
        XCTAssertNotNil(Color(hex: "#fff"))
        XCTAssertNotNil(Color(hex: "#FF8800"))
        XCTAssertNil(Color(hex: "fff"))         // missing #
        XCTAssertNil(Color(hex: "#xyz"))        // not hex
    }
}
