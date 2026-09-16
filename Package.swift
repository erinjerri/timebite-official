// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeBiteCore",
    platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "TimeBiteCore", targets: ["TimeBiteCore"]),
        .library(name: "TimeBiteData", targets: ["TimeBiteData"]),
        .library(name: "TimeBiteUI", targets: ["TimeBiteUI"]),
        .library(name: "TimeBiteSync", targets: ["TimeBiteSync"])
    ],
    targets: [
        .target(name: "TimeBiteCore", path: "TimeBiteCore"),
        .target(name: "TimeBiteData", dependencies: ["TimeBiteCore"], path: "Packages/TimeBiteData"),
        .target(name: "TimeBiteUI", dependencies: ["TimeBiteCore", "TimeBiteData"], path: "Packages/TimeBiteUI"),
        .target(name: "TimeBiteSync", dependencies: ["TimeBiteCore", "TimeBiteData"], path: "Packages/TimeBiteSync"),
        .testTarget(
            name: "TimeBiteCoreTests",
            dependencies: ["TimeBiteCore", "TimeBiteData", "TimeBiteSync"],
            resources: [.copy("Fixtures")]
        )
    ]
)
