// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SiteThread",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "SiteThreadCore"),
        .executableTarget(name: "SiteThread", dependencies: ["SiteThreadCore"]),
        .testTarget(name: "SiteThreadCoreTests", dependencies: ["SiteThreadCore"]),
    ]
)
