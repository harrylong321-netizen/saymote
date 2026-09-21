import AppKit
import CoreGraphics
import Foundation

enum SupportedRemoteID: String, CaseIterable, Identifiable, Codable {
    case chromecast
    case x6

    /// 界面上只暴露这一个型号（用户要求先隐藏 X6）。X6 的代码路径、锚点、
    /// 自测全部保留，要恢复支持把这个数组改回去即可，界面会自动变回下拉。
    static var visibleCases: [SupportedRemoteID] { [.chromecast] }

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
        // 音量加减在右侧面（正面图只看得到摇杆的凸起，y 0.20–0.33），
        // 上＋下−，x 取凸起所在的 0.922。
        "0C": CGPoint(x: 0.922, y: 0.232),    // 音量＋
        "0D": CGPoint(x: 0.922, y: 0.298),    // 音量－
        // 电源/信源在机身底部的药丸排（⏻ · ⇥，y≈0.716）。之前误记成
        // 「图上没有这两个键」，实际是漏量了——坐标是两个图标质心的量测值。
        "01": CGPoint(x: 0.290, y: 0.716),    // 电源
        "11": CGPoint(x: 0.702, y: 0.716)     // 信源
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

/// 按键映射页的排版：两栏行 + 中间遥控器图。
///
/// 界面上已经不画常驻连线了（用户要求去掉），但每行「悬停时要亮哪个键」
/// 仍然需要坐标，所以折线计算保留：`Line.points` 的首尾就是行边缘和按键位置。
/// 另外「同一栏的行按按键的上下顺序排」依然是硬要求——否则悬停时眼睛要从
/// 乱序的行里找键。分栏不是简单按 x < 0.5 切——那样 X6 会变成 5 行 / 10 行
/// （超过一栏放得下的 10 行），得有解才行。所以这里用一个爬山搜索（单步 →
/// 卡住时试两步）在「交叉数、横穿机身数、溢出、两栏不均衡、连线总长」上取
/// 最优解，结果按型号缓存（锚点是静态的，只算一次）。
enum RemoteMappingLayout {
    /// 行高 34、行间距 0：行之间改用 0.5pt 分隔线区分，不再是「一行一个灰块」，
    /// 所以不需要间距。一栏最多 10 行 → 340pt，仍在这一栏 341pt 的高度预算内。
    /// 两个值一起决定连线的起点 y（`place()` 里的 centerY），视图必须按同样的
    /// 公式摆行，否则连线会跟行错位。
    static let rowHeight: CGFloat = 34
    static let rowGap: CGFloat = 0
    static let topInset: CGFloat = 2
    static let maxRowsPerColumn = 10
    static let centerColumnWidth: CGFloat = 144
    static let columnGap: CGFloat = 12
    static let imageHeight: CGFloat = 330
    /// 控制台内容宽度固定 735，分栏按这个宽度算（缓存也按它算）。
    static let referenceWidth: CGFloat = 735

    struct Row {
        let button: RemoteButtonDefinition
        let anchor: CGPoint?
        let centerY: CGFloat
    }

    struct Line {
        let buttonID: String
        /// 折线：行边缘 → 拐点 → 按键。前一段是斜线、后一段是横线
        /// （必要时末尾还有一小段接到圆点的短竖线）。
        let points: [CGPoint]
        let active: Bool
    }

    struct Layout {
        let left: [Row]
        let right: [Row]
        let lines: [Line]
        let imageOriginX: CGFloat
        let imageWidth: CGFloat
    }

    private struct Geometry {
        let sideWidth: CGFloat
        let leftEdge: CGFloat
        let rightEdge: CGFloat
        let imageOriginX: CGFloat
        let imageWidth: CGFloat
    }

    private struct Metrics: Comparable {
        let crossings: Int
        /// 行在自己那栏、按键却长在机身的另一半——焦点连线会横穿遥控器。
        /// 排在「交叉数」之后当次要目标：不能为了它牺牲「连线不相交」这条硬要求。
        let crossOver: Int
        let overflow: Int
        let imbalance: Int
        let length: Int

        static func < (lhs: Metrics, rhs: Metrics) -> Bool {
            if lhs.crossings != rhs.crossings { return lhs.crossings < rhs.crossings }
            if lhs.crossOver != rhs.crossOver { return lhs.crossOver < rhs.crossOver }
            if lhs.overflow != rhs.overflow { return lhs.overflow < rhs.overflow }
            if lhs.imbalance != rhs.imbalance { return lhs.imbalance < rhs.imbalance }
            return lhs.length < rhs.length
        }
    }

    private static var assignmentCache: [SupportedRemoteID: [String: Bool]] = [:]
    private static let cacheLock = NSLock()

    /// 斜线离行边缘多远开始拐成横线；横线之间至少留开的间隔。
    private static let bendOffset: CGFloat = 26
    private static let minHorizontalLength: CGFloat = 12
    private static let minHorizontalSpacing: CGFloat = 8

    private struct Placement {
        let left: [(button: RemoteButtonDefinition, anchor: CGPoint?, centerY: CGFloat)]
        let right: [(button: RemoteButtonDefinition, anchor: CGPoint?, centerY: CGFloat)]
        let polylines: [(buttonID: String, points: [CGPoint])]
    }

    /// `imageAspect` = 图宽 / 图高；只有它影响线段几何。
    static func layout(
        remote: SupportedRemoteID,
        width: CGFloat,
        imageAspect: CGFloat,
        isActive: (RemoteButtonDefinition) -> Bool
    ) -> Layout {
        let buttons = RemoteProfiles.buttons(for: remote)
        var anchored: [(RemoteButtonDefinition, CGPoint)] = []
        var unanchored: [RemoteButtonDefinition] = []
        for button in buttons {
            if let anchor = RemoteAnchors.anchor(forButton: button.id, remote: remote) {
                anchored.append((button, anchor))
            } else {
                unanchored.append(button)
            }
        }
        let geometry = geometry(width: width, imageAspect: imageAspect)
        let assignment = cachedAssignment(
            remote: remote,
            anchored: anchored,
            unanchoredCount: unanchored.count,
            imageAspect: imageAspect
        )
        let placement = place(
            assignment: assignment,
            anchored: anchored,
            unanchored: unanchored,
            geometry: geometry
        )
        let leftRows = placement.left.map {
            Row(button: $0.button, anchor: $0.anchor, centerY: $0.centerY)
        }
        let rightRows = placement.right.map {
            Row(button: $0.button, anchor: $0.anchor, centerY: $0.centerY)
        }
        let buttonByID = Dictionary(
            uniqueKeysWithValues: RemoteProfiles.buttons(for: remote).map { ($0.id, $0) }
        )
        let lines = placement.polylines.map { entry in
            Line(
                buttonID: entry.buttonID,
                points: entry.points,
                active: buttonByID[entry.buttonID].map(isActive) ?? true
            )
        }
        return Layout(
            left: leftRows,
            right: rightRows,
            lines: lines,
            imageOriginX: geometry.imageOriginX,
            imageWidth: geometry.imageWidth
        )
    }

    // MARK: - 分栏求解

    /// 给定分栏，算出两栏的行位置和每条连线折线（斜线 + 横线）。
    ///
    /// 横线落在按键的 y 上；同一栏里两条横线如果离得太近（例如方向盘上的
    /// 「确认」和「方向右」在同一高度），就把后一条往下让开一点，末尾再用
    /// 一小段竖线接回圆点，保证横线之间不重叠。
    private static func place(
        assignment: [String: Bool],
        anchored: [(RemoteButtonDefinition, CGPoint)],
        unanchored: [RemoteButtonDefinition],
        geometry: Geometry
    ) -> Placement {
        var columns: [Bool: [(RemoteButtonDefinition, CGPoint?)]] = [true: [], false: []]
        for (button, anchor) in anchored {
            columns[assignment[button.id] ?? false, default: []]
                .append((button, anchor))
        }
        let shorter: Bool = columns[true]!.count <= columns[false]!.count
        columns[shorter]?.append(contentsOf: unanchored.map { ($0, nil) })

        func placed(isLeft: Bool) -> [(button: RemoteButtonDefinition, anchor: CGPoint?, centerY: CGFloat)] {
            (columns[isLeft] ?? [])
                .sorted { lhs, rhs in
                    switch (lhs.1, rhs.1) {
                    case let (l?, r?): r.y == l.y ? l.x < r.x : l.y < r.y
                    case (nil, _): false
                    case (_, nil): true
                    }
                }
                .enumerated()
                .map { index, entry in
                    (
                        button: entry.0,
                        anchor: entry.1,
                        centerY: topInset
                            + CGFloat(index) * (rowHeight + rowGap)
                            + rowHeight / 2
                    )
                }
        }

        let leftRows = placed(isLeft: true)
        let rightRows = placed(isLeft: false)
        var polylines: [(buttonID: String, points: [CGPoint])] = []
        for (rows, edge) in [
            (leftRows, geometry.leftEdge),
            (rightRows, geometry.rightEdge)
        ] {
            // 横线用的 y：按按键 y 排好，靠得太近的往下让开。
            var previousHorizontalY: CGFloat = -.greatestFiniteMagnitude
            for row in rows {
                guard let anchor = row.anchor else { continue }
                let anchorX = geometry.imageOriginX + anchor.x * geometry.imageWidth
                let anchorY = anchor.y * imageHeight
                var horizontalY = anchorY
                if horizontalY - previousHorizontalY < minHorizontalSpacing {
                    horizontalY = previousHorizontalY + minHorizontalSpacing
                }
                previousHorizontalY = horizontalY
                // 拐点：斜线从行边缘出发，走 bendOffset 之后拐成横线；
                // 离图太近的按键就少拐一点，保证横线至少 12pt 看得见。
                let bendX: CGFloat
                if edge < geometry.imageOriginX {
                    bendX = min(anchorX - minHorizontalLength, edge + bendOffset)
                } else {
                    bendX = max(anchorX + minHorizontalLength, edge - bendOffset)
                }
                var points = [
                    CGPoint(x: edge, y: row.centerY),
                    CGPoint(x: bendX, y: horizontalY),
                    CGPoint(x: anchorX, y: horizontalY)
                ]
                if abs(horizontalY - anchorY) > 0.5 {
                    points.append(CGPoint(x: anchorX, y: anchorY))
                }
                polylines.append((buttonID: row.button.id, points: points))
            }
        }
        return Placement(left: leftRows, right: rightRows, polylines: polylines)
    }

    private static func cachedAssignment(
        remote: SupportedRemoteID,
        anchored: [(RemoteButtonDefinition, CGPoint)],
        unanchoredCount: Int,
        imageAspect: CGFloat
    ) -> [String: Bool] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = assignmentCache[remote] { return cached }
        let solved = solve(
            anchored: anchored,
            unanchoredCount: unanchoredCount,
            imageAspect: imageAspect
        )
        assignmentCache[remote] = solved
        return solved
    }

    private static func solve(
        anchored: [(RemoteButtonDefinition, CGPoint)],
        unanchoredCount: Int,
        imageAspect: CGFloat
    ) -> [String: Bool] {
        var assignment: [String: Bool] = [:]
        for (button, anchor) in anchored {
            assignment[button.id] = anchor.x < 0.5
        }
        var current = metrics(
            assignment: assignment,
            anchored: anchored,
            unanchoredCount: unanchoredCount,
            imageAspect: imageAspect
        )
        var steps = 0
        while steps < 200, current.crossings > 0 || current.overflow > 0 {
            var best: ([String: Bool], Metrics)?
            for (button, _) in anchored {
                var trial = assignment
                trial[button.id] = !(assignment[button.id] ?? true)
                let value = metrics(
                    assignment: trial,
                    anchored: anchored,
                    unanchoredCount: unanchoredCount,
                    imageAspect: imageAspect
                )
                if value < current, best == nil || value < best!.1 {
                    best = (trial, value)
                }
            }
            if let best {
                assignment = best.0
                current = best.1
                steps += 1
                continue
            }
            // 单步卡住：试两步组合逃出去（X6 用得到）。
            var escape: ([String: Bool], Metrics)?
            for i in anchored.indices {
                for j in anchored.indices where j > i {
                    var trial = assignment
                    trial[anchored[i].0.id]?.toggle()
                    trial[anchored[j].0.id]?.toggle()
                    let value = metrics(
                        assignment: trial,
                        anchored: anchored,
                        unanchoredCount: unanchoredCount,
                        imageAspect: imageAspect
                    )
                    if value < current, escape == nil || value < escape!.1 {
                        escape = (trial, value)
                    }
                }
            }
            guard let escape else { break }
            assignment = escape.0
            current = escape.1
            steps += 1
        }
        return assignment
    }

    private static func metrics(
        assignment: [String: Bool],
        anchored: [(RemoteButtonDefinition, CGPoint)],
        unanchoredCount: Int,
        imageAspect: CGFloat
    ) -> Metrics {
        let geometry = geometry(width: referenceWidth, imageAspect: imageAspect)
        let placement = place(
            assignment: assignment,
            anchored: anchored,
            // 无锚点的行接在栏末尾，不影响锚点行的 y，所以这里空着算即可。
            unanchored: [],
            geometry: geometry
        )
        let leftCount = placement.left.count
            + (placement.left.count <= placement.right.count ? unanchoredCount : 0)
        let rightCount = placement.right.count
            + (placement.left.count <= placement.right.count ? 0 : unanchoredCount)
        var segments: [(CGPoint, CGPoint)] = []
        var totalLength = 0.0
        for polyline in placement.polylines {
            for index in 0..<(polyline.points.count - 1) {
                let start = polyline.points[index]
                let end = polyline.points[index + 1]
                segments.append((start, end))
                totalLength += hypot(end.x - start.x, end.y - start.y)
            }
        }
        var crossings = 0
        for i in segments.indices {
            for j in segments.indices where j > i {
                if segmentsCross(
                    segments[i].0,
                    segments[i].1,
                    segments[j].0,
                    segments[j].1
                ) {
                    crossings += 1
                }
            }
        }
        return Metrics(
            crossings: crossings,
            crossOver: crossOverCount(assignment: assignment, anchored: anchored),
            overflow: max(0, leftCount - maxRowsPerColumn)
                + max(0, rightCount - maxRowsPerColumn),
            imbalance: abs(leftCount - rightCount),
            length: Int(totalLength.rounded())
        )
    }

    /// 中线上（方向盘那一列）的按键放哪边都不算横穿，所以要留容差。
    /// 自测要用同一个阈值判断，所以不设 private。
    static let midlineTolerance: CGFloat = 0.08

    private static func crossOverCount(
        assignment: [String: Bool],
        anchored: [(RemoteButtonDefinition, CGPoint)]
    ) -> Int {
        var count = 0
        for (button, anchor) in anchored {
            guard abs(anchor.x - 0.5) > midlineTolerance else { continue }
            let belongsLeft = anchor.x < 0.5
            if (assignment[button.id] ?? false) != belongsLeft {
                count += 1
            }
        }
        return count
    }

    private static func segmentsCross(
        _ a1: CGPoint,
        _ a2: CGPoint,
        _ b1: CGPoint,
        _ b2: CGPoint
    ) -> Bool {
        func side(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat {
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        }
        let d1 = side(b1, b2, a1)
        let d2 = side(b1, b2, a2)
        let d3 = side(a1, a2, b1)
        let d4 = side(a1, a2, b2)
        return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0))
    }

    /// 「离这个点最近的那个键」，超出 `maxDistance` 就算没指到任何键。
    ///
    /// 图上的鼠标跟踪用它决定该亮哪个键。按最近距离判定而不是做一排方形热区：
    /// 方向盘五个键中心只隔 28pt，方形热区必然重叠，重叠处谁在上面谁抢到事件，
    /// 会出现「指 A 亮 B」或「指上去没反应」。
    static func nearestButtonID(
        to point: CGPoint,
        lines: [Line],
        maxDistance: CGFloat
    ) -> String? {
        var best: (id: String, distance: CGFloat)?
        for line in lines {
            guard let end = line.points.last else { continue }
            let distance = hypot(end.x - point.x, end.y - point.y)
            guard distance <= maxDistance else { continue }
            if best == nil || distance < best!.distance {
                best = (line.buttonID, distance)
            }
        }
        return best?.id
    }

    private static func geometry(width: CGFloat, imageAspect: CGFloat) -> Geometry {
        let sideWidth = max(0, (width - centerColumnWidth - 2 * columnGap) / 2)
        let imageWidth = imageHeight * imageAspect
        return Geometry(
            sideWidth: sideWidth,
            leftEdge: sideWidth,
            rightEdge: sideWidth + centerColumnWidth + 2 * columnGap,
            imageOriginX: sideWidth + columnGap + (centerColumnWidth - imageWidth) / 2,
            imageWidth: imageWidth
        )
    }
}
