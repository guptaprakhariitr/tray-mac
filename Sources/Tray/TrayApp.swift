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
        AppLog.bootstrap(appName: "Tray",
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
                    if vm.clips.items.isEmpty {
                        // Seed with sample data so the drawer isn't empty on first run.
                        vm.add("https://plainware.com/tray")
                        vm.add("#FF8800")
                        vm.add("the quick brown fox")
                    }
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
            VStack(spacing: 16) {
                AboutView(appName: "Tray",
                          version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                          tagline: "Clipboard, shelf and notes in one edge drawer.",
                          replaces: "paid clipboard managers")
                LicenseSettingsView(license: license, remote: remote)
            }
            .padding(24)
            .frame(width: 460)
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
            .onAppear { if !onboarded { showOnboarding = true } }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    appName: "Tray",
                    tagline: "Clipboard history, a file shelf and quick notes — in one drawer.",
                    glyph: "tray.full.fill",
                    accent: Color(red: 0.18, green: 0.65, blue: 0.55),
                    steps: [
                        .init(systemImage: "doc.on.clipboard", title: "Clipboard history",
                              detail: "Everything you copy is kept here — search it and pin what matters."),
                        .init(systemImage: "tray.and.arrow.down", title: "File shelf",
                              detail: "Drag files in to stash them, then drag them out wherever you need."),
                        .init(systemImage: "note.text", title: "Quick notes",
                              detail: "Jot things down — type a calculation like 12 * 3 and it solves inline."),
                    ],
                    primaryTitle: "Get Started",
                    footnote: "Everything stays on your Mac.",
                    primaryAction: { onboarded = true; showOnboarding = false },
                    secondaryAction: { onboarded = true; showOnboarding = false }
                )
            }
    }
}
