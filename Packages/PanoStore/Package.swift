// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanoStore",
    platforms: [.macOS("15.4")],
    products: [.library(name: "PanoStore", targets: ["PanoStore"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1")],
    targets: [
        .target(name: "PanoStore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "PanoStoreTests", dependencies: ["PanoStore"]),
    ],
    swiftLanguageModes: [.v6]
)
