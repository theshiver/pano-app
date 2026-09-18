// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanoUI",
    platforms: [.macOS("15.4")],
    products: [.library(name: "PanoUI", targets: ["PanoUI"])],
    dependencies: [
        .package(path: "../PanoCore"),
        .package(path: "../PanoTransforms"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.3.0"),
    ],
    targets: [
        .target(
            name: "PanoUI",
            dependencies: ["PanoCore", "PanoTransforms", "Highlightr"]
        ),
        .testTarget(name: "PanoUITests", dependencies: ["PanoUI"]),
    ],
    swiftLanguageModes: [.v6]
)
