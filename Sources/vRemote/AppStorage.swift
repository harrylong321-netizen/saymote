import Foundation

enum AppStorage {
    static let loggingEnabledKey = "loggingEnabled"
    static let inputTriggerKeyKey = "inputTriggerKey"

    static let logsDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/vRemote", isDirectory: true)
    }()

    static let logFile = logsDirectory.appendingPathComponent("vRemote.log")

    static let applicationSupportDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/vRemote", isDirectory: true)
    }()

    static func prepare() {
        UserDefaults.standard.register(defaults: [
            loggingEnabledKey: false,
            inputTriggerKeyKey: InputTriggerKey.leftOption.rawValue,
        ])
        migrateTriggerKeyIfNeeded()
        ensureDirectory(logsDirectory)
        ensureDirectory(applicationSupportDirectory)

        // vRemote has its own storage namespace and never touches V1 data.
    }

    static var loggingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: loggingEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: loggingEnabledKey) }
    }


    /// 老版本存的是不分左右的 option / command / control，升级后要映射到
    /// 对应的「侧」——按旧版实际发送的键迁移，行为保持不变。只做一次。
    private static func migrateTriggerKeyIfNeeded() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: inputTriggerKeyKey),
              let migrated = InputTriggerKey.migrated(fromLegacy: raw)
        else { return }
        defaults.set(migrated.rawValue, forKey: inputTriggerKeyKey)
    }

    static var inputTriggerKey: InputTriggerKey {
        get {
            let raw = UserDefaults.standard.string(forKey: inputTriggerKeyKey)
            return InputTriggerKey(rawValue: raw ?? "")
                ?? InputTriggerKey.migrated(fromLegacy: raw ?? "")
                ?? .leftOption
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: inputTriggerKeyKey)
        }
    }

    static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    static func byteSize(of url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            ), values.isRegularFile == true else { continue }
            total += UInt64(values.fileSize ?? 0)
        }
        return total
    }

    static func clearFiles(in directory: URL) {
        let fm = FileManager.default
        ensureDirectory(directory)
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    static func formattedSize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }
}
