// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MiseShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "MiseShared", targets: ["MiseShared"]),
    ],
    targets: [
        .target(name: "MiseShared"),
        .testTarget(name: "MiseSharedTests", dependencies: ["MiseShared"]),
    ]
)
