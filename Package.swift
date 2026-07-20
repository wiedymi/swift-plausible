// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Plausible",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Plausible", targets: ["Plausible"]),
        .library(name: "PlausibleCore", targets: ["PlausibleCore"]),
        .library(name: "PlausibleAPI", targets: ["PlausibleAPI"]),
        .library(name: "PlausibleTracker", targets: ["PlausibleTracker"]),
    ],
    targets: [
        .target(name: "PlausibleCore"),
        .target(name: "PlausibleAPI", dependencies: ["PlausibleCore"]),
        .target(name: "PlausibleTracker", dependencies: ["PlausibleCore"]),
        .target(name: "Plausible", dependencies: ["PlausibleCore", "PlausibleAPI", "PlausibleTracker"]),
        .testTarget(name: "PlausibleTests", dependencies: ["Plausible"]),
    ]
)
