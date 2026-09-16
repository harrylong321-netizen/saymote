// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "vRemote",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(name: "TelemetryDeck", path: "../SwiftSDK-local")
    ],
    targets: [
        .executableTarget(
            name: "vRemote",
            dependencies: [
                .product(name: "TelemetryDeck", package: "TelemetryDeck")
            ],
            path: "Sources/vRemote",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
