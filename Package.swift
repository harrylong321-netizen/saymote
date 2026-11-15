// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Saymote",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(name: "TelemetryDeck", path: "../SwiftSDK-local")
    ],
    targets: [
        .executableTarget(
            name: "Saymote",
            dependencies: [
                .product(name: "TelemetryDeck", package: "TelemetryDeck")
            ],
            path: "Sources/Saymote",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
