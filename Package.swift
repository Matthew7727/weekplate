// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeekplateCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WeekplateCore", path: "Weekplate/Core"),
        .testTarget(name: "WeekplateCoreTests", dependencies: ["WeekplateCore"], path: "Tests")
    ]
)
