// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "ScreenshotKit", targets: ["ScreenshotKit"]),
        .library(name: "LogKit", targets: ["LogKit"]),
        .library(name: "SettingsKit", targets: ["SettingsKit"]),
        .library(name: "RemoteConfigKit", targets: ["RemoteConfigKit"]),
        .library(name: "LicenseKit", targets: ["LicenseKit"]),
        .library(name: "UpdateKit", targets: ["UpdateKit"]),
        .library(name: "VersionGateKit", targets: ["VersionGateKit"]),
        .library(name: "CommonUI", targets: ["CommonUI"]),
    ],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "ScreenshotKit", dependencies: ["DesignSystem"]),
        .target(name: "LogKit"),
        .target(name: "SettingsKit"),
        .target(name: "RemoteConfigKit"),
        .target(name: "LicenseKit", dependencies: ["RemoteConfigKit"]),
        .target(name: "UpdateKit", dependencies: ["RemoteConfigKit"]),
        .target(name: "VersionGateKit", dependencies: ["LogKit"]),
        .target(name: "CommonUI", dependencies: [
            "DesignSystem", "SettingsKit", "RemoteConfigKit", "LicenseKit", "UpdateKit", "VersionGateKit",
        ]),
        // CLT-runnable check harness (no XCTest/Swift Testing, which need full Xcode).
        // The formal XCTest suite in Tests/ is built under the Xcode track.
        .executableTarget(name: "CoreChecks", dependencies: [
            "LicenseKit", "UpdateKit", "RemoteConfigKit", "VersionGateKit",
        ]),
    ]
)
