import SwiftUI
import DesignSystem
import RemoteConfigKit
import LicenseKit
import UpdateKit

/// Shared "About" panel content for every app.
public struct AboutView: View {
    let appName: String
    let version: String
    let tagline: String
    let replaces: String
    public init(appName: String, version: String, tagline: String, replaces: String) {
        self.appName = appName; self.version = version
        self.tagline = tagline; self.replaces = replaces
    }
    public var body: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "app.gift.fill").font(.system(size: 56)).foregroundStyle(DS.Color.accent)
            Text(appName).font(DS.Font.display)
            Text(tagline).font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Label("Free & open source", systemImage: "checkmark.seal.fill")
                    Label("Your data never leaves your Mac", systemImage: "lock.fill")
                    Label("A free replacement for \(replaces)", systemImage: "arrow.uturn.down.circle.fill")
                }.font(DS.Font.body)
            }
            Text("Version \(version)").font(DS.Font.caption).foregroundStyle(DS.Color.tertiaryLabel)
        }
        .padding(DS.Space.xl)
        .frame(width: 420)
    }
}

/// License entry row used in settings (only meaningful once monetization is on).
public struct LicenseSettingsView: View {
    @ObservedObject var license: LicenseStore
    @ObservedObject var remote: RemoteConfig
    @State private var entry: String = ""

    public init(license: LicenseStore, remote: RemoteConfig) {
        self.license = license; self.remote = remote
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("License").font(DS.Font.headline)
                if !remote.paidEnabled {
                    Text("All features are currently free. No license required.")
                        .font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
                } else {
                    statusLine
                    HStack {
                        TextField("Paste license key", text: $entry)
                            .textFieldStyle(.roundedBorder).font(DS.Font.mono)
                        Button("Activate") { _ = license.apply(entry) }
                            .buttonStyle(.dsPrimary)
                            .disabled(entry.isEmpty)
                    }
                }
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch license.status {
        case .valid(let l): Label("Active — \(l.email)", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .expired:      Label("Expired", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .invalid(let r): Label(r, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        case .unlicensed:   Label("Not activated", systemImage: "lock.fill").foregroundStyle(DS.Color.secondaryLabel)
        }
    }
}

/// Full-window blocking gate shown when a force-update is required.
public struct ForceUpdateView: View {
    let min: String
    let current: String
    let onUpdate: () -> Void
    public init(min: String, current: String, onUpdate: @escaping () -> Void) {
        self.min = min; self.current = current; self.onUpdate = onUpdate
    }
    public var body: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "arrow.down.circle.fill").font(.system(size: 64)).foregroundStyle(DS.Color.accent)
            Text("Update required").font(DS.Font.title)
            Text("You're on \(current). Version \(min) or later is required to continue.")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryLabel)
            Button("Update now", action: onUpdate).buttonStyle(.dsPrimary)
        }
        .padding(DS.Space.xl)
        .frame(minWidth: 360, minHeight: 280)
    }
}
