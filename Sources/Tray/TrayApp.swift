import SwiftUI
import AppKit
import TrayUI
import RemoteConfigKit
import LicenseKit
import CommonUI

@main
struct TrayApp: App {
    @StateObject private var vm = TrayViewModel()
    @StateObject private var remote = RemoteConfig() // flags OFF by default
    @StateObject private var license = LicenseStore(verifier: nil, productID: "tray")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .onAppear {
                    if vm.clips.items.isEmpty {
                        // Seed with sample data so the drawer isn't empty on first run.
                        vm.add("https://plainware.com/tray")
                        vm.add("#FF8800")
                        vm.add("the quick brown fox")
                    }
                    Task { await remote.refresh() }
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
