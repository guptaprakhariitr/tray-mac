import Foundation
import Combine

/// Remote-controlled feature flags. **Everything defaults OFF / safe** so apps
/// ship "dark" and features are flipped on later from the config backend
/// (Firebase Remote Config) with no app update — per the monetization decision.
///
/// The actual paid-feature gate lives inside each app's private engine; this
/// struct is the shared client view of the flags.
public struct FeatureFlags: Codable, Equatable, Sendable {
    /// Master switch for all paid/pro features. OFF until we choose to monetize.
    public var paidFeaturesEnabled: Bool
    /// Whether the in-app updater (Sparkle) is allowed to check/notify.
    public var updatesEnabled: Bool
    /// Whether a hard force-update gate is active.
    public var forceUpdate: Bool
    /// Minimum app version permitted when `forceUpdate` is on (semver "1.2.0").
    public var minSupportedVersion: String
    /// Free-form per-app flags (e.g. "glaze.aiRedaction": true).
    public var extras: [String: Bool]

    public init(
        paidFeaturesEnabled: Bool = false,
        updatesEnabled: Bool = false,
        forceUpdate: Bool = false,
        minSupportedVersion: String = "0.0.0",
        extras: [String: Bool] = [:]
    ) {
        self.paidFeaturesEnabled = paidFeaturesEnabled
        self.updatesEnabled = updatesEnabled
        self.forceUpdate = forceUpdate
        self.minSupportedVersion = minSupportedVersion
        self.extras = extras
    }

    /// The safe, shipped-OFF baseline used until a backend says otherwise.
    public static let safeDefaults = FeatureFlags()

    public func extra(_ key: String, default def: Bool = false) -> Bool {
        extras[key] ?? def
    }
}

/// A source of feature flags. Swap implementations (local defaults now,
/// Firebase Remote Config later) without touching app code.
public protocol RemoteConfigProvider: Sendable {
    /// Synchronous best-known flags (returns defaults before first fetch).
    func currentFlags() -> FeatureFlags
    /// Fetch the latest flags from the backend. Must never throw past the
    /// boundary — return last-known/defaults on failure.
    func fetchFlags() async -> FeatureFlags
}

/// Default provider: always returns safe (OFF) defaults, optionally overridden
/// by anything cached locally. Used until the Firebase provider is wired in.
public struct LocalDefaultsProvider: RemoteConfigProvider {
    private let flags: FeatureFlags
    public init(flags: FeatureFlags = .safeDefaults) { self.flags = flags }
    public func currentFlags() -> FeatureFlags { flags }
    public func fetchFlags() async -> FeatureFlags { flags }
}

/// Observable façade the SwiftUI layer binds to. Holds the current flags,
/// refreshes from the provider, and persists the last good values so the app
/// behaves consistently offline.
@MainActor
public final class RemoteConfig: ObservableObject {
    @Published public private(set) var flags: FeatureFlags

    private let provider: RemoteConfigProvider
    private let cacheKey = "mac_utilities.remoteconfig.cache"
    private let store: UserDefaults

    public init(provider: RemoteConfigProvider = LocalDefaultsProvider(),
                store: UserDefaults = .standard) {
        self.provider = provider
        self.store = store
        if let data = store.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(FeatureFlags.self, from: data) {
            self.flags = cached
        } else {
            self.flags = provider.currentFlags()
        }
    }

    /// Pull the latest flags; persists them for offline consistency.
    public func refresh() async {
        let latest = await provider.fetchFlags()
        self.flags = latest
        if let data = try? JSONEncoder().encode(latest) {
            store.set(data, forKey: cacheKey)
        }
    }

    // Convenience accessors used throughout the UI.
    public var paidEnabled: Bool { flags.paidFeaturesEnabled }
    public var updatesEnabled: Bool { flags.updatesEnabled }
    public func feature(_ key: String, default def: Bool = false) -> Bool {
        flags.extra(key, default: def)
    }
}
