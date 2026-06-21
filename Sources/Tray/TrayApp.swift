import SwiftUI
import AppKit
import TrayUI
import RemoteConfigKit
import LicenseKit
import CommonUI
import VersionGateKit
import LogKit

@main
struct TrayApp: App {
    @StateObject private var vm = TrayViewModel()
    @StateObject private var remote = RemoteConfig() // flags OFF by default
    @StateObject private var license = LicenseStore(verifier: nil, productID: "tray")
    @StateObject private var versionGate = VersionGate.fromBundle(appKey: "tray")
        ?? VersionGate(projectId: "", apiKey: "", appKey: "tray", currentBuild: 0, currentVersion: "0")

    init() {
        AppLog.bootstrap(appName: "TrayShelf",
                         version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .versionGate(versionGate)
                .onAppear {
                    AppLog.info("main window shown", category: "ui")
                    Task { await versionGate.check() }
                    Task {
                        await remote.refresh()
                        AppLog.info("remote config refreshed — paid=\(remote.paidEnabled) updates=\(remote.updatesEnabled)", category: "config")
                    }
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Capture Clipboard") { vm.captureClipboard() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button("Clipboard") { vm.pane = .clipboard }.keyboardShortcut("1", modifiers: .command)
                Button("Shelf") { vm.pane = .shelf }.keyboardShortcut("2", modifiers: .command)
                Button("Notes") { vm.pane = .notes }.keyboardShortcut("3", modifiers: .command)
            }
        }

        Settings {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AboutView(appName: "TrayShelf",
                              version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                              tagline: "Clipboard, shelf and notes in one edge drawer.",
                              replaces: "paid clipboard managers")
                    GroupBox("Security & privacy") {
                        SecurityInfoView(showTitle: false).padding(8)
                    }
                    LicenseSettingsView(license: license, remote: remote)
                }
                .padding(24)
                .frame(width: 460)
            }
            .frame(height: 640)
        }
    }
}

/// Wraps the drawer and shows the first-run welcome sheet.
private struct RootView: View {
    @EnvironmentObject var vm: TrayViewModel
    @AppStorage("com.plainware.tray.onboarding.v1") private var onboarded = false
    @State private var showOnboarding = false

    var body: some View {
        ContentView()
            .splashOverlay()
            .onAppear { if !onboarded { showOnboarding = true } }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    appName: "TrayShelf",
                    tagline: "Clipboard history, a file shelf and quick notes — in one drawer.",
                    glyph: "tray.full.fill",
                    accent: Color(red: 0.18, green: 0.65, blue: 0.55),
                    steps: [
                        .init(systemImage: "doc.on.clipboard", title: "Clipboard history",
                              detail: "Turn on Auto and everything you copy is kept here — search it, open the full text, and pin what matters."),
                        .init(systemImage: "tray.and.arrow.down", title: "File shelf",
                              detail: "Drag files in to stash them, then drag them out wherever you need."),
                        .init(systemImage: "note.text", title: "Quick notes",
                              detail: "Jot things down — type a calculation like 12 * 3 and it solves inline."),
                        .init(systemImage: "checkmark.shield.fill", title: "Private & encrypted",
                              detail: "Your history is encrypted on your Mac with a key in the Keychain — macOS may ask you to allow that the first time (choose “Always Allow”). Set a passcode any time from the lock menu to mask your clips."),
                    ],
                    primaryTitle: "Get Started",
                    footnote: "Everything stays on your Mac — encrypted, no account, no tracking.",
                    primaryAction: { onboarded = true; showOnboarding = false },
                    secondaryAction: { onboarded = true; showOnboarding = false }
                )
            }
    }
}
