import SwiftUI
import AppKit
import DesignSystem
import VersionGateKit

public extension View {
    /// Overlays a blocking force-update screen when the gate requires it, and a
    /// dismissible "update available" banner otherwise. Apply to the app's root.
    func versionGate(_ gate: VersionGate) -> some View {
        modifier(VersionGateModifier(gate: gate))
    }
}

struct VersionGateModifier: ViewModifier {
    @ObservedObject var gate: VersionGate
    @State private var dismissedUpdate = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) { updateBanner }
            .overlay { forceCover }
    }

    @ViewBuilder private var updateBanner: some View {
        if case let .updateAvailable(latest) = gate.status, !dismissedUpdate {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(DS.Color.accent)
                Text("Version \(latest) is available.").font(DS.Font.body)
                Spacer()
                if let url = gate.info?.downloadURL.flatMap(URL.init(string:)) {
                    Button("Update") { NSWorkspace.shared.open(url) }.buttonStyle(.borderedProminent).controlSize(.small)
                }
                Button { dismissedUpdate = true } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(DS.Color.secondaryLabel)
            }
            .padding(DS.Space.sm).padding(.horizontal, DS.Space.sm)
            .background(DS.Color.bgElevated, in: Capsule())
            .overlay(Capsule().strokeBorder(DS.Color.separator, lineWidth: 0.5))
            .shadow(radius: 8, y: 2)
            .padding(DS.Space.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private var forceCover: some View {
        if case let .forceUpdate(message, downloadURL) = gate.status {
            ZStack {
                DS.Color.bg.ignoresSafeArea()
                VStack(spacing: DS.Space.md) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 64)).foregroundStyle(DS.Color.accent)
                    Text("Update required").font(DS.Font.title)
                    Text(message).font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
                        .multilineTextAlignment(.center).frame(maxWidth: 360)
                    if let url = downloadURL.flatMap(URL.init(string:)) {
                        Button("Update now") { NSWorkspace.shared.open(url) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                }
                .padding(DS.Space.xl)
            }
            .transition(.opacity)
        }
    }
}
