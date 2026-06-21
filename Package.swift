// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tray",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Packages/Core"),
        .package(path: "Engines/DrawerEngine"),
    ],
    targets: [
        // The open-source shell UI (becomes the public OSS module later).
        .target(
            name: "TrayUI",
            dependencies: [
                "DrawerEngine",
                .product(name: "DesignSystem", package: "Core"),
                .product(name: "CommonUI", package: "Core"),
                .product(name: "SettingsKit", package: "Core"),
                .product(name: "RemoteConfigKit", package: "Core"),
                .product(name: "LicenseKit", package: "Core"),
                .product(name: "UpdateKit", package: "Core"),
                .product(name: "LogKit", package: "Core"),
            ],
            path: "Sources/TrayUI"
        ),
        .executableTarget(
            name: "Tray",
            dependencies: [
                "TrayUI",
                .product(name: "CommonUI", package: "Core"),
                .product(name: "RemoteConfigKit", package: "Core"),
                .product(name: "LicenseKit", package: "Core"),
                .product(name: "LogKit", package: "Core"),
            ],
            path: "Sources/Tray"
        ),
        .executableTarget(
            name: "TrayChecks",
            dependencies: [
                "TrayUI",
                "DrawerEngine",
                .product(name: "ScreenshotKit", package: "Core"),
            ],
            path: "Sources/TrayChecks"
        ),
        .testTarget(
            name: "DrawerUITests",
            dependencies: ["TrayUI", "DrawerEngine"],
            path: "Tests/DrawerUITests"
        ),
    ]
)
