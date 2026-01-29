// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnttuiiClient",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AnttuiiClient",
            path: "Sources"
        ),
    ]
)
