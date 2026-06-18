import SwiftUI

// A reference-grounded Mac App Store screenshot design system, shared across the
// Plainware suite. Top-store conventions: one short billboard caption per shot,
// the real app UI inside macOS window chrome, a consistent branded background,
// generous margins. Everything here is ImageRenderer-safe — only gradients,
// shapes, strokes and Text (NO blur / NO .shadow), so it renders fully off-screen.
//
// Views lay out at the FULL pixel size (scale 1.0), so all metrics scale off a
// 1440-pt-wide reference via `s(_:)` to stay crisp at 1440×900 and 2560×1600.

public struct StoreTheme {
    public let accent: Color
    public let bgTop: Color
    public let bgBottom: Color
    public let glow: Color          // radial accent glow over the background
    public let onBg: Color          // primary caption text
    public let onBgDim: Color       // secondary caption text
    public let windowChrome: Color  // title-bar fill of the framed window

    public init(accent: Color, bgTop: Color, bgBottom: Color,
                glow: Color? = nil, onBg: Color = .white,
                onBgDim: Color? = nil, windowChrome: Color = Color(white: 0.16)) {
        self.accent = accent
        self.bgTop = bgTop
        self.bgBottom = bgBottom
        self.glow = glow ?? accent
        self.onBg = onBg
        self.onBgDim = onBgDim ?? onBg.opacity(0.68)
        self.windowChrome = windowChrome
    }

    /// A refined dark, accent-tinted theme (the suite default).
    public static func dark(_ accent: Color) -> StoreTheme {
        StoreTheme(accent: accent,
                   bgTop: blend(accent, Color(white: 0.10), 0.82),
                   bgBottom: Color(white: 0.035),
                   glow: accent)
    }

    static func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let na = NSColor(a).usingColorSpace(.deviceRGB) ?? .black
        let nb = NSColor(b).usingColorSpace(.deviceRGB) ?? .black
        return Color(red: na.redComponent * (1 - t) + nb.redComponent * t,
                     green: na.greenComponent * (1 - t) + nb.greenComponent * t,
                     blue: na.blueComponent * (1 - t) + nb.blueComponent * t)
    }
}

/// Branded background: diagonal gradient + dual accent glows + a soft vignette
/// for depth (premium-store look). ImageRenderer-safe (gradients only).
public struct StoreBackground: View {
    let theme: StoreTheme
    let w: CGFloat
    public init(_ theme: StoreTheme, width: CGFloat) { self.theme = theme; self.w = width }
    public var body: some View {
        ZStack {
            LinearGradient(colors: [theme.bgTop, theme.bgBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [theme.glow.opacity(0.34), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: w * 0.82)
            RadialGradient(colors: [theme.glow.opacity(0.12), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: w * 0.6)
            // vignette: darkens the corners so the framed window pops forward
            RadialGradient(colors: [.clear, Color.black.opacity(0.28)],
                           center: .center, startRadius: w * 0.28, endRadius: w * 0.82)
        }
    }
}

/// A faked soft drop shadow (ImageRenderer can't do .shadow/.blur): a stack of
/// progressively larger, fainter rounded rects offset downward behind a view.
struct FauxShadow: View {
    let corner: CGFloat
    let s: (CGFloat) -> CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                RoundedRectangle(cornerRadius: corner + s(2.2) * CGFloat(i), style: .continuous)
                    .fill(Color.black.opacity(0.07))
                    .padding(s(-2.2) * CGFloat(i))
                    .offset(y: s(12) + s(3.2) * CGFloat(i))
            }
        }
    }
}

/// A realistic macOS window frame around arbitrary content (traffic lights +
/// centered title + rounded corners + hairline border). No blur/shadow.
public struct MacWindow<Content: View>: View {
    let title: String
    let s: (CGFloat) -> CGFloat
    let content: Content
    public init(title: String, scale: @escaping (CGFloat) -> CGFloat, @ViewBuilder content: () -> Content) {
        self.title = title; self.s = scale; self.content = content()
    }
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(white: 0.17)
                HStack(spacing: s(8)) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: s(13), height: s(13))
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: s(13), height: s(13))
                    Circle().fill(Color(red: 0.18, green: 0.80, blue: 0.27)).frame(width: s(13), height: s(13))
                    Spacer()
                }
                .padding(.horizontal, s(18))
                Text(title)
                    .font(.system(size: s(15), weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(height: s(46))
            content
        }
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: s(16), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: s(16), style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: s(1)))
        .background(FauxShadow(corner: s(16), s: s))   // soft floating shadow behind the window
    }
}

/// A small accent pill used above captions ("PLAINWARE", a feature tag, etc.).
public struct StoreTag: View {
    let text: String, theme: StoreTheme, s: (CGFloat) -> CGFloat
    public init(_ text: String, theme: StoreTheme, scale: @escaping (CGFloat) -> CGFloat) {
        self.text = text; self.theme = theme; self.s = scale
    }
    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: s(15), weight: .bold)).tracking(s(2))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, s(14)).padding(.vertical, s(7))
            .background(Capsule().fill(theme.accent.opacity(0.14)))
            .overlay(Capsule().strokeBorder(theme.accent.opacity(0.35), lineWidth: s(1)))
    }
}

/// Captioned feature shot: short billboard headline + subhead on top, the app
/// UI framed in a macOS window below. The conversion-tested default layout.
public struct FeatureShot<Content: View>: View {
    let theme: StoreTheme
    let tag: String?
    let headline: String
    let subhead: String
    let windowTitle: String
    let size: CGSize
    let content: Content

    public init(theme: StoreTheme, tag: String? = nil, headline: String, subhead: String,
                windowTitle: String, size: CGSize, @ViewBuilder content: () -> Content) {
        self.theme = theme; self.tag = tag; self.headline = headline
        self.subhead = subhead; self.windowTitle = windowTitle; self.size = size
        self.content = content()
    }

    public var body: some View {
        let s: (CGFloat) -> CGFloat = { $0 * size.width / 1440 }
        ZStack {
            StoreBackground(theme, width: size.width)
            VStack(spacing: s(34)) {
                VStack(spacing: s(14)) {
                    if let tag { StoreTag(tag, theme: theme, scale: s) }
                    Text(headline)
                        .font(.system(size: s(60), weight: .heavy)).tracking(s(-0.5))
                        .foregroundStyle(theme.onBg)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subhead)
                        .font(.system(size: s(26), weight: .medium))
                        .foregroundStyle(theme.onBgDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, s(80))
                MacWindow(title: windowTitle, scale: s) { content }
                    .frame(width: s(1120))
            }
            .padding(.vertical, s(70))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Hero shot: big left-aligned value proposition with the app window angled in
/// from the right — the strong opening frame of a store listing.
public struct HeroShot2<Content: View>: View {
    let theme: StoreTheme
    let appName: String
    let tagline: String
    let bullets: [String]
    let windowTitle: String
    let size: CGSize
    let content: Content

    public init(theme: StoreTheme, appName: String, tagline: String, bullets: [String],
                windowTitle: String, size: CGSize, @ViewBuilder content: () -> Content) {
        self.theme = theme; self.appName = appName; self.tagline = tagline
        self.bullets = bullets; self.windowTitle = windowTitle; self.size = size
        self.content = content()
    }

    public var body: some View {
        let s: (CGFloat) -> CGFloat = { $0 * size.width / 1440 }
        ZStack {
            StoreBackground(theme, width: size.width)
            HStack(spacing: s(56)) {
                VStack(alignment: .leading, spacing: s(22)) {
                    StoreTag("Plainware", theme: theme, scale: s)
                    Text(appName)
                        .font(.system(size: s(96), weight: .heavy)).tracking(s(-1))
                        .foregroundStyle(theme.onBg)
                    Text(tagline)
                        .font(.system(size: s(34), weight: .semibold))
                        .foregroundStyle(theme.onBg.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: s(16)) {
                        ForEach(bullets, id: \.self) { b in
                            HStack(spacing: s(14)) {
                                ZStack {
                                    Circle().fill(theme.accent).frame(width: s(30), height: s(30))
                                    Text("✓").font(.system(size: s(16), weight: .bold)).foregroundStyle(.white)
                                }
                                Text(b).font(.system(size: s(25))).foregroundStyle(theme.onBgDim)
                            }
                        }
                    }
                    .padding(.top, s(8))
                }
                .frame(width: s(520), alignment: .leading)
                MacWindow(title: windowTitle, scale: s) { content }
                    .frame(width: s(760))
            }
            .padding(.horizontal, s(90))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: size.width, height: size.height)
    }
}
