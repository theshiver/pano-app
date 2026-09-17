// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanoCore",
    platforms: [.macOS("15.4")],
    products: [.library(name: "PanoCore", targets: ["PanoCore"])],
    dependencies: [.package(path: "../PanoStore")],
    targets: [
        .target(name: "PanoCore", dependencies: ["PanoStore"]),
        .testTarget(name: "PanoCoreTests", dependencies: ["PanoCore"]),
    ],
    swiftLanguageModes: [.v6]
)
