// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanoUI",
    platforms: [.macOS("15.4")],
    products: [.library(name: "PanoUI", targets: ["PanoUI"])],
    dependencies: [.package(path: "../PanoCore"), .package(path: "../PanoTransforms")],
    targets: [
        .target(name: "PanoUI", dependencies: ["PanoCore", "PanoTransforms"]),
        .testTarget(name: "PanoUITests", dependencies: ["PanoUI"]),
    ],
    swiftLanguageModes: [.v6]
)
