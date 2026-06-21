import SwiftUI
import DesignSystem

/// Drives the one-shot launch splash. `showSplash` starts `true` and is flipped
/// to `false` by `dismiss()` (after the auto-timer, or on click/keypress). Kept
/// as a small observable so the flow is testable without a running UI.
@MainActor
public final class SplashModel: ObservableObject {
    @Published public private(set) var showSplash: Bool

    /// App identity surfaced on the splash + persistent UI.
    public static let appName = "TrayShelf"
    public static let tagline = "Your clipboard, files & notes — one keystroke away."
    public static let meaning = "Clipboard history, a drag-shelf, and quick notes in an encrypted drawer."
    public static let glyph = "tray.full.fill"
    public static let accent = Color(red: 0.18, green: 0.65, blue: 0.55)

    public init(showSplash: Bool = true) {
        self.showSplash = showSplash
    }

    /// Hide the splash. Idempotent — safe to call from the timer and a tap.
    public func dismiss() {
        showSplash = false
    }
}

/// A centered launch card shown once per launch over the main window. Auto-
/// dismisses after ~1.2s with a fade/scale, and also dismisses on click or key
/// press so it never traps the user. Honors Reduce Motion (fade only).
public struct SplashView: View {
    @ObservedObject var model: SplashModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: SplashModel) { self.model = model }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [DS.Color.bg, SplashModel.accent.opacity(0.10)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: DS.Space.md) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [SplashModel.accent, SplashModel.accent.opacity(0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .overlay(Image(systemName: SplashModel.glyph)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white))
                    .shadow(color: SplashModel.accent.opacity(0.35), radius: 12, y: 6)

                Text(SplashModel.appName).font(DS.Font.title)
                Text(SplashModel.tagline)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.label)
                    .multilineTextAlignment(.center)
                Text(SplashModel.meaning)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.lg)
            }
            .padding(DS.Space.xl)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(fade) { model.dismiss() } }
        .transition(reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 1.04)))
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(fade) { model.dismiss() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(SplashModel.appName). \(SplashModel.tagline)")
    }

    private var fade: Animation { .easeOut(duration: 0.35) }
}

/// Overlay modifier: stacks `SplashView` over the host content and routes a
/// key press to dismiss it. Apply to the main window's root view.
public struct SplashOverlay: ViewModifier {
    @StateObject private var model = SplashModel()

    public init() {}

    public func body(content: Content) -> some View {
        ZStack {
            content
            if model.showSplash {
                SplashView(model: model)
                    .zIndex(1)
                    .onExitCommand { withAnimation(.easeOut(duration: 0.35)) { model.dismiss() } }
            }
        }
    }
}

public extension View {
    /// Show the once-per-launch launch splash over this view.
    func splashOverlay() -> some View { modifier(SplashOverlay()) }
}
