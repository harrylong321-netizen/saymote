// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Saymote",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Saymote",
            path: "Sources/Saymote",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
