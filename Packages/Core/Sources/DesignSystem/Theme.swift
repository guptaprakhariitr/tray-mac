import SwiftUI

/// Shared visual language for all mac_utilities apps. Light + dark aware,
/// semantic rather than literal so individual apps can re-tint the accent.
public enum DS {

    // MARK: Spacing (8pt grid)
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 40
    }

    // MARK: Radius
    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 20
    }

    // MARK: Semantic colors
    public enum Color {
        public static let accent = SwiftUI.Color.accentColor
        public static let bg = SwiftUI.Color(nsColor: .windowBackgroundColor)
        public static let bgElevated = SwiftUI.Color(nsColor: .controlBackgroundColor)
        public static let separator = SwiftUI.Color(nsColor: .separatorColor)
        public static let label = SwiftUI.Color(nsColor: .labelColor)
        public static let secondaryLabel = SwiftUI.Color(nsColor: .secondaryLabelColor)
        public static let tertiaryLabel = SwiftUI.Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: Typography
    public enum Font {
        public static let display = SwiftUI.Font.system(size: 34, weight: .bold, design: .rounded)
        public static let title = SwiftUI.Font.system(size: 22, weight: .semibold)
        public static let headline = SwiftUI.Font.system(size: 15, weight: .semibold)
        public static let body = SwiftUI.Font.system(size: 13)
        public static let caption = SwiftUI.Font.system(size: 11)
        public static let mono = SwiftUI.Font.system(size: 12, design: .monospaced)
    }
}

/// A soft "card" surface used across settings/results panes.
public struct DSCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .padding(DS.Space.md)
            .background(DS.Color.bgElevated, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Color.separator, lineWidth: 0.5)
            )
    }
}

/// Primary call-to-action button style shared by all apps.
public struct DSPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.headline)
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .background(DS.Color.accent.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .foregroundStyle(.white)
            .contentShape(Rectangle())
    }
}

public extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle { .init() }
}
