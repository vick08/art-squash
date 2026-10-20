// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "vo-art-squash",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "vo-art-squash", path: "Sources/vo-art-squash")
    ]
)
