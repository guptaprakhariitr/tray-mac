// swift-tools-version:5.9
import PackageDescription

// DrawerEngine — the clipboard/shelf/notes core for Tray. In the OSS release
// this is consumed as a precompiled XCFramework binary; here (private repo) it
// builds from source.
let package = Package(
    name: "DrawerEngine",
    platforms: [.macOS(.v14)],
    products: [.library(name: "DrawerEngine", targets: ["DrawerEngine"])],
    targets: [
        .target(name: "DrawerEngine"),
        .testTarget(name: "DrawerEngineTests", dependencies: ["DrawerEngine"]),
    ]
)
