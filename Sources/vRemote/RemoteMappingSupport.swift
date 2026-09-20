import AppKit
import CoreGraphics
import Foundation

enum SupportedRemoteID: String, CaseIterable, Identifiable, Codable {
    case chromecast
    case x6

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chromecast: "Chromecast Voice Remote"
        case .x6: "X6 Remote"
        }
    }

    var signature: String {
        switch self {
        case .chromecast: "18D1 · 9450"
        case .x6: "1D5A · C081"
        }
    }
}

struct RemoteButtonDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let defaultTarget: RemoteMappingTarget
    let voiceControlled: Bool
    let remappable: Bool

    init(
        id: String,
        title: String,
        symbol: String,
        defaultTarget: RemoteMappingTarget,
        voiceControlled: Bool = false,
        remappable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.defaultTarget = defaultTarget
        self.voiceControlled = voiceControlled
        self.remappable = remappable
    }
}

enum RemoteProfiles {
    static let chromecastButtons: [RemoteButtonDefinition] = [
        .init(id: "03", title: L10n.text("方向上", "Up"), symbol: "arrow.up", defaultTarget: .arrowUp),
        .init(id: "04", title: L10n.text("方向下", "Down"), symbol: "arrow.down", defaultTarget: .arrowDown),
        .init(id: "05", title: L10n.text("方向左", "Left"), symbol: "arrow.left", defaultTarget: .arrowLeft),
        .init(id: "06", title: L10n.text("方向右", "Right"), symbol: "arrow.right", defaultTarget: .arrowRight),
        .init(id: "07", title: L10n.text("确认", "Select"), symbol: "circle.inset.filled", defaultTarget: .returnKey),
        .init(id: "0B", title: L10n.text("返回", "Back"), symbol: "chevron.backward", defaultTarget: .escape),
        .init(id: "0A", title: "Home", symbol: "house", defaultTarget: .showDesktop),
        .init(id: "0E", title: "YouTube", symbol: "play.rectangle", defaultTarget: .disabled),
        .init(id: "voice", title: L10n.text("语音", "Voice"), symbol: "mic", defaultTarget: .doubaoVoice, voiceControlled: true),
        .init(id: "08", title: L10n.text("静音", "Mute"), symbol: "speaker.slash", defaultTarget: .mute),
        .init(id: "0F", title: "Netflix", symbol: "n.square", defaultTarget: .disabled),
        .init(id: "01", title: L10n.text("电源", "Power"), symbol: "power", defaultTarget: .disabled),
        .init(id: "11", title: L10n.text("信源", "Input"), symbol: "rectangle.on.rectangle", defaultTarget: .disabled),
        .init(id: "0C", title: L10n.text("音量＋", "Volume Up"), symbol: "speaker.plus", defaultTarget: .volumeUp),
        .init(id: "0D", title: L10n.text("音量－", "Volume Down"), symbol: "speaker.minus", defaultTarget: .volumeDown),
    ]

    static func buttons(for remote: SupportedRemoteID) -> [RemoteButtonDefinition] {
        switch remote {
        case .chromecast: chromecastButtons
        case .x6: x6Buttons
        }
    }

    static let x6Buttons: [RemoteButtonDefinition] = [
        .init(id: "mouseMode", title: L10n.text("鼠标模式", "Mouse Mode"), symbol: "cursorarrow.motionlines", defaultTarget: .disabled, remappable: false),
        .init(id: "k2A", title: "Delete", symbol: "delete.left", defaultTarget: .deleteBackward),
        .init(id: "cE2", title: L10n.text("静音", "Mute"), symbol: "speaker.slash", defaultTarget: .mute),
        .init(id: "c224", title: L10n.text("返回", "Back"), symbol: "chevron.backward", defaultTarget: .escape),
        .init(id: "k65", title: L10n.text("菜单", "Menu"), symbol: "line.3.horizontal", defaultTarget: .disabled),
        .init(id: "c196", title: L10n.text("浏览器/搜索", "Browser / Search"), symbol: "magnifyingglass", defaultTarget: .spotlight),
        .init(id: "k52", title: L10n.text("方向上", "Up"), symbol: "arrow.up", defaultTarget: .arrowUp),
        .init(id: "k51", title: L10n.text("方向下", "Down"), symbol: "arrow.down", defaultTarget: .arrowDown),
        .init(id: "k50", title: L10n.text("方向左", "Left"), symbol: "arrow.left", defaultTarget: .arrowLeft),
        .init(id: "k4F", title: L10n.text("方向右", "Right"), symbol: "arrow.right", defaultTarget: .arrowRight),
        .init(id: "k28", title: "OK", symbol: "circle.inset.filled", defaultTarget: .returnKey),
        .init(id: "k4B", title: "PG+", symbol: "arrow.up.to.line", defaultTarget: .pageUp),
        .init(id: "k4E", title: "PG−", symbol: "arrow.down.to.line", defaultTarget: .pageDown),
        .init(id: "voice", title: L10n.text("语音", "Voice"), symbol: "mic", defaultTarget: .doubaoVoice, voiceControlled: true),
        .init(id: "cE9", title: L10n.text("音量＋", "Volume Up"), symbol: "speaker.plus", defaultTarget: .volumeUp),
        .init(id: "cEA", title: L10n.text("音量－", "Volume Down"), symbol: "speaker.minus", defaultTarget: .volumeDown),
        .init(id: "s01", title: L10n.text("电源", "Power"), symbol: "power", defaultTarget: .disabled),
    ]
}

enum RemoteMappingTarget: String, CaseIterable, Identifiable, Codable, Hashable {
    case disabled
    case doubaoVoice
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case returnKey
    case escape
    case deleteBackward
    case tab
    case space
    case home
    case end
    case pageUp
    case pageDown
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case showDesktop
    case spotlight
    case commandC
    case commandV
    case commandZ
    case openApp
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: L10n.text("禁用", "Disabled")
        case .doubaoVoice: L10n.text("豆包语音输入", "Doubao Voice Input")
        case .arrowUp: L10n.text("方向上", "Up Arrow")
        case .arrowDown: L10n.text("方向下", "Down Arrow")
        case .arrowLeft: L10n.text("方向左", "Left Arrow")
        case .arrowRight: L10n.text("方向右", "Right Arrow")
        case .returnKey: "Return"
        case .escape: "Escape"
        case .deleteBackward: "Delete"
        case .tab: "Tab"
        case .space: L10n.text("空格", "Space")
        case .home: "Home"
        case .end: "End"
        case .pageUp: "Page Up"
        case .pageDown: "Page Down"
        case .volumeUp: L10n.text("系统音量＋", "System Volume Up")
        case .volumeDown: L10n.text("系统音量－", "System Volume Down")
        case .mute: L10n.text("系统静音", "System Mute")
        case .playPause: L10n.text("播放/暂停", "Play / Pause")
        case .showDesktop: L10n.text("显示桌面", "Show Desktop")
        case .spotlight: "Spotlight (⌘Space)"
        case .commandC: L10n.text("复制 (⌘C)", "Copy (⌘C)")
        case .commandV: L10n.text("粘贴 (⌘V)", "Paste (⌘V)")
        case .commandZ: L10n.text("撤销 (⌘Z)", "Undo (⌘Z)")
        case .openApp: L10n.text("打开指定 App", "Open an app")
        case .custom: L10n.text("录制任意按键…", "Record a key…")
        }
    }

    var keyboard: (keyCode: CGKeyCode, flags: CGEventFlags)? {
        switch self {
        case .arrowUp: (0x7E, [])
        case .arrowDown: (0x7D, [])
        case .arrowLeft: (0x7B, [])
        case .arrowRight: (0x7C, [])
        case .returnKey: (0x24, [])
        case .escape: (0x35, [])
        case .deleteBackward: (0x33, [])
        case .tab: (0x30, [])
        case .space: (0x31, [])
        case .home: (0x73, [])
        case .end: (0x77, [])
        case .pageUp: (0x74, [])
        case .pageDown: (0x79, [])
        case .showDesktop: (0x67, [.maskSecondaryFn])
        case .spotlight: (0x31, [.maskCommand])
        case .commandC: (0x08, [.maskCommand])
        case .commandV: (0x09, [.maskCommand])
        case .commandZ: (0x06, [.maskCommand])
        default: nil
        }
    }

    var mediaKey: Int32? {
        switch self {
        case .volumeUp: 0
        case .volumeDown: 1
        case .mute: 7
        case .playPause: 16
        default: nil
        }
    }

    func post(isDown: Bool) {
        guard self != .disabled, self != .doubaoVoice else { return }
        if let keyboard {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyboard.keyCode,
                keyDown: isDown
            ) else { return }
            event.flags = keyboard.flags
            event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
            event.post(tap: .cghidEventTap)
        } else if let mediaKey, isDown {
            postMediaKey(mediaKey)
        }
    }

    private func postMediaKey(_ key: Int32) {
        func post(state: Int32) {
            let data1 = Int((key << 16) | (state << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )?.cgEvent else { return }
            event.post(tap: .cghidEventTap)
        }
        post(state: 0xA)
        post(state: 0xB)
    }
}

struct RemoteCustomShortcut: Codable, Hashable {
    let keyCode: UInt16
    let flags: UInt64
    let label: String

    func post(isDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(keyCode),
            keyDown: isDown
        ) else { return }
        event.flags = CGEventFlags(rawValue: flags)
        event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}

/// 「按这个键就切到某个 App」的目标。
///
/// 保存 bundle id 为主（应用挪了位置也能找到），路径作为兜底；
/// 名称只用于界面显示，避免每次刷新都去查一次。
struct RemoteAppMapping: Codable, Hashable {
    let bundleID: String
    let name: String
    let path: String

    /// 打开或切到这个 App。已经在运行时会被激活到前台。
    func open() {
        let workspace = NSWorkspace.shared
        let url = workspace.urlForApplication(withBundleIdentifier: bundleID)
            ?? (FileManager.default.fileExists(atPath: path)
                ? URL(fileURLWithPath: path)
                : nil)
        guard let url else {
            print("[MAPPING] ⚠️ 找不到 App：\(name)（\(bundleID)）")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                print("[MAPPING] ⚠️ 打开 \(name) 失败：\(error.localizedDescription)")
            }
        }
    }
}

final class RemoteMappingStore: ObservableObject {
    static let shared = RemoteMappingStore()

    @Published private(set) var revision = 0
    private let defaults = UserDefaults.standard
    private let prefix = "remoteMapping."
    private let enabledPrefix = "remoteMappingEnabled."
    private let customPrefix = "remoteCustomMapping."
    private let appPrefix = "remoteAppMapping."

    private init() {}

    func isEnabled(_ remote: SupportedRemoteID) -> Bool {
        defaults.bool(forKey: enabledPrefix + remote.rawValue)
    }

    func setEnabled(_ enabled: Bool, for remote: SupportedRemoteID) {
        defaults.set(enabled, forKey: enabledPrefix + remote.rawValue)
        revision += 1
    }

    func target(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) -> RemoteMappingTarget {
        guard !button.voiceControlled else { return .doubaoVoice }
        guard button.remappable else { return .disabled }
        let key = prefix + remote.rawValue + "." + button.id
        guard let raw = defaults.string(forKey: key),
              let target = RemoteMappingTarget(rawValue: raw)
        else { return button.defaultTarget }
        return target
    }

    func setTarget(
        _ target: RemoteMappingTarget,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) {
        guard !button.voiceControlled, button.remappable else { return }
        defaults.set(
            target.rawValue,
            forKey: prefix + remote.rawValue + "." + button.id
        )
        revision += 1
    }

    func customShortcut(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) -> RemoteCustomShortcut? {
        let key = customPrefix + remote.rawValue + "." + button.id
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RemoteCustomShortcut.self, from: data)
    }

    func setCustomShortcut(
        _ shortcut: RemoteCustomShortcut,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) {
        let key = customPrefix + remote.rawValue + "." + button.id
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key)
            setTarget(.custom, for: button, remote: remote)
        }
    }

    func targetTitle(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) -> String {
        let value = target(for: button, remote: remote)
        if value == .custom,
           let shortcut = customShortcut(for: button, remote: remote) {
            return shortcut.label
        }
        if value == .openApp {
            return appMapping(for: button, remote: remote)?.name
                ?? L10n.text("选择应用…", "Choose app…")
        }
        return value.title
    }

    func appMapping(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) -> RemoteAppMapping? {
        let key = appPrefix + remote.rawValue + "." + button.id
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RemoteAppMapping.self, from: data)
    }

    func setAppMapping(
        _ mapping: RemoteAppMapping,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID
    ) {
        let key = appPrefix + remote.rawValue + "." + button.id
        if let data = try? JSONEncoder().encode(mapping) {
            defaults.set(data, forKey: key)
            setTarget(.openApp, for: button, remote: remote)
        }
    }

    func post(
        button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        isDown: Bool
    ) {
        let value = target(for: button, remote: remote)
        if value == .custom {
            customShortcut(for: button, remote: remote)?.post(isDown: isDown)
        } else if value == .openApp {
            // 只在按下时触发一次，避免按下/抬起各切一次。
            if isDown {
                appMapping(for: button, remote: remote)?.open()
            }
        } else {
            value.post(isDown: isDown)
        }
    }

    func reset(_ remote: SupportedRemoteID) {
        for button in RemoteProfiles.buttons(for: remote) {
            defaults.removeObject(
                forKey: prefix + remote.rawValue + "." + button.id
            )
            defaults.removeObject(
                forKey: customPrefix + remote.rawValue + "." + button.id
            )
            defaults.removeObject(
                forKey: appPrefix + remote.rawValue + "." + button.id
            )
        }
        revision += 1
    }
}

/// 遥控器按键在产品图上的位置（归一化 0–1：x 向右、y 向下，相对原图像素）。
///
/// 这里的坐标不是"看图标的"——是在 PNG 上算出来的：先用 alpha 通道求机身轮廓，
/// 再按亮度阈值找按键团块取质心，带字的键用 Vision OCR 的文字框交叉验证
/// （Chromecast 的 YouTube / NETFLIX、X6 的 Del / OK / PG+ / PG− 都是这么定的）。
/// 图上确实没有、或定位不到的按键留空，那几行就没有编号与圆点。
///
/// 复核：`work/make-anchor-preview.py` 会按这里的坐标画一张带编号的预览图，
/// 肉眼看一眼就知道哪个点没落在按键上。
enum RemoteAnchors {
    static func anchor(
        forButton id: String,
        remote: SupportedRemoteID
    ) -> CGPoint? {
        switch remote {
        case .chromecast: chromecast[id]
        case .x6: x6[id]
        }
    }

    /// Chromecast Voice Remote（产品图 388×1080）
    static let chromecast: [String: CGPoint] = [
        // 方向盘上的箭头在这张产品图里几乎看不见（对比度 1 个灰阶以内），
        // 所以四个方向按几何位置放在环带中线上：圆心 (0.500, 0.155)、
        // 外环半径约 142px、中间确认键半径约 41px → 环带中线半径约 91px。
        "03": CGPoint(x: 0.500, y: 0.070),    // 方向上（环带 12 点）
        "04": CGPoint(x: 0.500, y: 0.239),    // 方向下（环带 6 点）
        "05": CGPoint(x: 0.265, y: 0.155),    // 方向左（环带 9 点）
        "06": CGPoint(x: 0.734, y: 0.155),    // 方向右（环带 3 点）
        "07": CGPoint(x: 0.500, y: 0.155),    // 确认（方向盘圆心）
        "0B": CGPoint(x: 0.297, y: 0.348),    // 返回
        "0A": CGPoint(x: 0.298, y: 0.471),    // Home
        "0E": CGPoint(x: 0.298, y: 0.594),    // YouTube（OCR 读出文字）
        "voice": CGPoint(x: 0.694, y: 0.349), // 语音（深色键 + 四色点）
        "08": CGPoint(x: 0.689, y: 0.471),    // 静音
        "0F": CGPoint(x: 0.694, y: 0.594),    // Netflix（OCR 读出文字）
        "0C": CGPoint(x: 0.712, y: 0.715),    // 音量＋
        "0D": CGPoint(x: 0.287, y: 0.715)     // 音量－
        // 01 电源、11 信源：这张正面图上没有这两个键
    ]

    /// X6 Remote（产品图 289×863）
    static let x6: [String: CGPoint] = [
        "c224": CGPoint(x: 0.298, y: 0.161),  // 返回（左上圆键）
        "k2A": CGPoint(x: 0.522, y: 0.161),   // Delete（OCR 读出 "Del"）
        "k65": CGPoint(x: 0.740, y: 0.161),   // 菜单（右上圆键）
        "cE2": CGPoint(x: 0.280, y: 0.225),   // 静音
        "c196": CGPoint(x: 0.520, y: 0.225),  // 浏览器/搜索
        "k52": CGPoint(x: 0.523, y: 0.293),   // 方向上
        "k51": CGPoint(x: 0.523, y: 0.443),   // 方向下
        "k50": CGPoint(x: 0.298, y: 0.368),   // 方向左
        "k4F": CGPoint(x: 0.748, y: 0.368),   // 方向右
        "k28": CGPoint(x: 0.523, y: 0.368),   // OK（OCR 读出 "OK"）
        "k4B": CGPoint(x: 0.286, y: 0.491),   // PG+（OCR）
        "k4E": CGPoint(x: 0.286, y: 0.582),   // PG−（OCR）
        "voice": CGPoint(x: 0.503, y: 0.536), // 语音（麦克风图标）
        "cE9": CGPoint(x: 0.740, y: 0.491),   // 音量＋
        "cEA": CGPoint(x: 0.740, y: 0.582)    // 音量−
        // mouseMode 鼠标模式、s01 电源：图上看不到
    ]
}
