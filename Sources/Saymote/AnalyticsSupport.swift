import Foundation

enum AppAnalytics {
    static func configure() {
        // Telemetry disabled in open-source distribution.
    }

    static func signal(_ name: String, parameters: [String: String] = [:]) {
        _ = (name, parameters)
    }
}
