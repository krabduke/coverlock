// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Coverlock",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Coverlock", path: "Sources/Coverlock"),
    ]
)
