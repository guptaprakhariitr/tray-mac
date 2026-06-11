# Firebase Remote Config provider (enable later)

`RemoteConfigKit` ships with `LocalDefaultsProvider` (all flags OFF) so the dev
loop needs no Firebase SDK. To turn the backend on later, add a second SPM
target `RemoteConfigKitFirebase` that depends on the Firebase Apple SDK and
implements `RemoteConfigProvider`:

```swift
import FirebaseRemoteConfig
import RemoteConfigKit

public struct FirebaseFlagsProvider: RemoteConfigProvider {
    private let rc = RemoteConfig.remoteConfig()
    public init(minimumFetchInterval: TimeInterval = 3600) {
        let s = RemoteConfigSettings(); s.minimumFetchInterval = minimumFetchInterval
        rc.configSettings = s
        rc.setDefaults(["paidFeaturesEnabled": false as NSObject,
                        "updatesEnabled": false as NSObject,
                        "forceUpdate": false as NSObject])
    }
    public func currentFlags() -> FeatureFlags { decode(rc) }
    public func fetchFlags() async -> FeatureFlags {
        _ = try? await rc.fetchAndActivate(); return decode(rc)
    }
    private func decode(_ rc: RemoteConfig) -> FeatureFlags {
        FeatureFlags(
            paidFeaturesEnabled: rc["paidFeaturesEnabled"].boolValue,
            updatesEnabled: rc["updatesEnabled"].boolValue,
            forceUpdate: rc["forceUpdate"].boolValue,
            minSupportedVersion: rc["minSupportedVersion"].stringValue ?? "0.0.0")
    }
}
```

Then in each app's composition root:
`RemoteConfig(provider: FirebaseFlagsProvider())`.

Requires `GoogleService-Info.plist` in the app bundle (gitignored). Privacy:
declare Firebase data collection in App Privacy + `PrivacyInfo.xcprivacy`. To
avoid data collection entirely, implement the same protocol against a tiny
self-hosted JSON endpoint instead — no SDK, no telemetry, identical flags.
