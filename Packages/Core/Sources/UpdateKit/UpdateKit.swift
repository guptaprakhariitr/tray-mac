import Foundation
import RemoteConfigKit

/// Semantic version comparison (no external deps). Tolerant of "1", "1.2",
/// "1.2.3", and a leading "v".
public struct SemVer: Comparable, Equatable, CustomStringConvertible, Sendable {
    public let parts: [Int]
    public init(_ string: String) {
        let cleaned = string.hasPrefix("v") ? String(string.dropFirst()) : string
        // drop any pre-release/build suffix after '-' or '+'
        let core = cleaned.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? cleaned
        self.parts = core.split(separator: ".").map { Int($0) ?? 0 }
    }
    private func at(_ i: Int) -> Int { i < parts.count ? parts[i] : 0 }
    public static func < (l: SemVer, r: SemVer) -> Bool {
        for i in 0..<max(l.parts.count, r.parts.count) {
            if l.at(i) != r.at(i) { return l.at(i) < r.at(i) }
        }
        return false
    }
    // Padding-aware equality so "1.2" == "1.2.0" (don't use synthesized array ==).
    public static func == (l: SemVer, r: SemVer) -> Bool { !(l < r) && !(r < l) }
    public var description: String { parts.map(String.init).joined(separator: ".") }
}

public enum UpdateGate: Equatable, Sendable {
    case ok                 // current behavior; no action
    case updatesDisabled    // remote flag off → updater stays silent
    case forced(min: String, current: String) // hard block: must update
}

/// Pure, testable policy that combines the remote flags with the running app
/// version. The actual download/install is delegated to a `SoftwareUpdater`
/// (Sparkle binding, added in the distribution track).
public enum UpdatePolicy {
    public static func evaluate(flags: FeatureFlags, currentVersion: String) -> UpdateGate {
        if flags.forceUpdate {
            let min = SemVer(flags.minSupportedVersion)
            let cur = SemVer(currentVersion)
            if cur < min { return .forced(min: flags.minSupportedVersion, current: currentVersion) }
        }
        return flags.updatesEnabled ? .ok : .updatesDisabled
    }
}

/// Update mechanism abstraction. A no-op default ships now (updates remotely
/// OFF); a `SparkleUpdater` conforming to this is added in the distribution
/// track (Sparkle 2 via SPM) without touching app code.
public protocol SoftwareUpdater: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

public final class NoopUpdater: SoftwareUpdater {
    public init() {}
    public var canCheckForUpdates: Bool { false }
    public func checkForUpdates() {}
}
