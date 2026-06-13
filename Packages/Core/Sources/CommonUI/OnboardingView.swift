import SwiftUI
import DesignSystem

/// One "here's what you can do" row in the welcome screen.
public struct OnboardingStep: Identifiable, Sendable {
    public let id = UUID()
    public let systemImage: String
    public let title: String
    public let detail: String
    public init(systemImage: String, title: String, detail: String) {
        self.systemImage = systemImage; self.title = title; self.detail = detail
    }
}

/// A clean, to-the-point first-run welcome: what the app is, what you can do,
/// and one obvious button to start. Shared across all Plainware apps.
///
/// Gate it with `@AppStorage("<bundle>.onboarding.v1")` and present in a sheet:
///
///     .sheet(isPresented: $showOnboarding) { OnboardingView(...) }
public struct OnboardingView: View {
    let appName: String
    let tagline: String
    let glyph: String
    let accent: Color
    let steps: [OnboardingStep]
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let footnote: String?

    public init(appName: String, tagline: String, glyph: String, accent: Color,
                steps: [OnboardingStep], primaryTitle: String,
                secondaryTitle: String? = "Maybe later", footnote: String? = nil,
                primaryAction: @escaping () -> Void, secondaryAction: (() -> Void)? = nil) {
        self.appName = appName; self.tagline = tagline; self.glyph = glyph; self.accent = accent
        self.steps = steps; self.primaryTitle = primaryTitle; self.secondaryTitle = secondaryTitle
        self.footnote = footnote; self.primaryAction = primaryAction; self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(spacing: DS.Space.lg) {
            VStack(spacing: DS.Space.sm) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .overlay(Image(systemName: glyph).font(.system(size: 40, weight: .medium)).foregroundStyle(.white))
                    .shadow(color: accent.opacity(0.35), radius: 12, y: 6)
                Text("Welcome to \(appName)").font(DS.Font.title)
                Text(tagline).font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DS.Space.sm)

            VStack(alignment: .leading, spacing: DS.Space.md) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: DS.Space.md) {
                        Image(systemName: step.systemImage)
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(accent)
                            .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(DS.Font.headline)
                            Text(step.detail).font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            VStack(spacing: DS.Space.sm) {
                Button(action: primaryAction) {
                    Text(primaryTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(accent)
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction).buttonStyle(.plain)
                        .font(DS.Font.body).foregroundStyle(DS.Color.secondaryLabel)
                }
                if let footnote {
                    Text(footnote).font(DS.Font.caption).foregroundStyle(DS.Color.tertiaryLabel)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(DS.Space.xl)
        .frame(width: 440)
    }
}
