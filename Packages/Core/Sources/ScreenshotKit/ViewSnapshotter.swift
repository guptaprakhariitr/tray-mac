import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Renders SwiftUI views to PNG files completely off-screen — no window, no
/// screen-recording permission. Used for (a) the developer's visual QA loop and
/// (b) generating pixel-exact Mac App Store screenshots.
public enum ViewSnapshotter {

    /// Mac App Store accepts only these 16:10 sizes (one set scales to all Macs).
    public enum StoreSize: CaseIterable {
        case s1280x800, s1440x900, s2560x1600, s2880x1800
        public var pixels: CGSize {
            switch self {
            case .s1280x800: return CGSize(width: 1280, height: 800)
            case .s1440x900: return CGSize(width: 1440, height: 900)
            case .s2560x1600: return CGSize(width: 2560, height: 1600)
            case .s2880x1800: return CGSize(width: 2880, height: 1800)
            }
        }
    }

    public enum SnapshotError: Error { case renderFailed, encodeFailed }

    /// Render `view` at an exact point size & scale to a PNG on disk.
    @MainActor
    @discardableResult
    public static func renderPNG<V: View>(
        _ view: V,
        size: CGSize,
        scale: CGFloat = 2.0,
        to url: URL
    ) throws -> URL {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.isOpaque = true
        guard let cg = renderer.cgImage else { throw SnapshotError.renderFailed }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = size // points; pixel dims come from the cgImage (size * scale)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodeFailed
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    /// Render a view sized to fill an exact App Store pixel resolution.
    /// `scale` 1.0 means the view is laid out at the full pixel size.
    @MainActor
    @discardableResult
    public static func renderStoreShot<V: View>(
        _ view: V,
        size: StoreSize,
        to url: URL
    ) throws -> URL {
        try renderPNG(view, size: size.pixels, scale: 1.0, to: url)
    }
}
