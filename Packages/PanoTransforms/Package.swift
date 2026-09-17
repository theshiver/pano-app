// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanoTransforms",
    platforms: [.macOS("15.4")],
    products: [.library(name: "PanoTransforms", targets: ["PanoTransforms"])],
    dependencies: [],
    targets: [
        .target(name: "PanoTransforms", dependencies: []),
        .testTarget(name: "PanoTransformsTests", dependencies: ["PanoTransforms"]),
    ],
    swiftLanguageModes: [.v6]
)
