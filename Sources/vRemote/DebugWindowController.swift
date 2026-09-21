import AppKit
import ApplicationServices
import CoreBluetooth
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

enum PermissionKind: String, Identifiable, CaseIterable {
    case doubaoInput
    case accessibility
    case inputMonitoring
    case bluetooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doubaoInput: L10n.text("豆包麦克风设置", "Doubao Microphone Setup")
        case .accessibility: L10n.text("辅助功能权限", "Accessibility Permission")
        case .inputMonitoring: L10n.text("输入监控权限", "Input Monitoring Permission")
        case .bluetooth: L10n.text("蓝牙权限", "Bluetooth Permission")
        }
    }

    var settingsURL: URL? {
        let anchor: String
        switch self {
        case .doubaoInput: return nil
        case .accessibility: anchor = "Privacy_Accessibility"
        case .inputMonitoring: anchor = "Privacy_ListenEvent"
        case .bluetooth: anchor = "Privacy_Bluetooth"
        }
        return URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        )
    }

    var screenshotNames: [String] {
        switch self {
        case .doubaoInput:
            [
                "permission-app-management",
                "doubaoinput0",
                "doubaoinput1",
                "doubaoinput2"
            ]
        case .accessibility: ["permission-accessibility", "permission-accessibility"]
        case .inputMonitoring: ["permission-input-monitoring", "permission-input-monitoring"]
        case .bluetooth: ["permission-bluetooth", "permission-bluetooth"]
        }
    }

    var guidance: [String] {
        switch self {
        case .doubaoInput:
            return [
                L10n.text(
                    "首次直接打开豆包设置时，macOS 可能询问“App 管理”；请允许 vRemote 启动豆包输入法的设置组件。",
                    "The first direct launch may ask for App Management. Allow vRemote to open Doubao's settings component."
                ),
                L10n.text(
                    "打开菜单栏输入法菜单，点击“豆包输入法设置”。",
                    "Open the input menu in the menu bar and choose Doubao Input Method Settings."
                ),
                L10n.text(
                    "进入“语音输入”，找到“麦克风选择”，点击当前选项。",
                    "Open Voice Input, locate Microphone Selection, and click the current option."
                ),
                L10n.text(
                    "选择“虚拟声卡”（豆包列表里这一项显示为 vRemoteDr 2ch）。",
                    "Select “Virtual sound card” (listed as vRemoteDr 2ch in Doubao's list)."
                ),
                L10n.text(
                    "不要选“自动检测”。实测它不会跟随 vRemoter 切换，往往一直用内置麦克风，而且选上之后短按关不掉录音。",
                    "Do not choose Automatic Detection. Measured behaviour: it does not follow vRemoter, tends to keep using the built-in microphone, and once selected a short press cannot stop recording."
                )
            ]
        case .accessibility:
            return [
                L10n.text(
                    "系统设置会打开到“隐私与安全性 → 辅助功能”。",
                    "System Settings will open Privacy & Security > Accessibility."
                ),
                L10n.text(
                    "找到 vRemote（或 vRemoter）并打开开关。列表中没有时，点加号选择应用。",
                    "Enable vRemote or vRemoter. If it is missing, use the plus button to add the app."
                )
            ]
        case .inputMonitoring:
            return [
                L10n.text(
                    "系统设置会打开到“隐私与安全性 → 输入监控”。",
                    "System Settings will open Privacy & Security > Input Monitoring."
                ),
                L10n.text(
                    "找到 vRemote（或 vRemoter）并打开开关。macOS 提示重新启动时允许它重新打开。",
                    "Enable vRemote or vRemoter, then allow macOS to relaunch it when prompted."
                )
            ]
        case .bluetooth:
            return [
                L10n.text(
                    "系统设置会打开到“隐私与安全性 → 蓝牙”。",
                    "System Settings will open Privacy & Security > Bluetooth."
                ),
                L10n.text(
                    "找到 vRemote（或 vRemoter）并打开开关，然后返回应用等待遥控器重新连接。",
                    "Enable vRemote or vRemoter, then return to the app and wait for the remote to reconnect."
                )
            ]
        }
    }

    var pageCount: Int { screenshotNames.count }

    func screenshotName(for page: Int) -> String {
        screenshotNames[min(max(page, 0), pageCount - 1)]
    }
}

private enum ConsoleTheme {
    // 白色底主题：panel 是窗口底、surface 是卡片、surface2 是卡片里的嵌层，
    // black 沿用旧名字表示「凹下去的中性面」——现在是浅灰而不是黑。
    static let panel = Color(red: 0.965, green: 0.969, blue: 0.976)
    static let surface = Color.white
    static let surface2 = Color(red: 0.949, green: 0.957, blue: 0.969)
    static let line = Color(red: 0.812, green: 0.831, blue: 0.859)
    static let lineSoft = Color(red: 0.886, green: 0.898, blue: 0.918)
    static let text = Color(red: 0.106, green: 0.118, blue: 0.145)
    static let secondary = Color(red: 0.345, green: 0.376, blue: 0.427)
    static let tertiary = Color(red: 0.420, green: 0.450, blue: 0.510)
    // 状态色在白底上要压暗，否则对比度不够。
    static let green = Color(red: 0.075, green: 0.520, blue: 0.270)
    static let amber = Color(red: 0.680, green: 0.380, blue: 0.020)
    static let amberDeep = Color(red: 0.996, green: 0.949, blue: 0.863)
    static let red = Color(red: 0.808, green: 0.176, blue: 0.180)
    static let redDeep = Color(red: 0.996, green: 0.918, blue: 0.914)
    static let goodDeep = Color(red: 0.898, green: 0.961, blue: 0.914)
    static let black = Color(red: 0.925, green: 0.937, blue: 0.953)
    /// 压在浅绿底（`goodDeep`）上的绿：白底用 `green`，浅绿底要用这个才够 4.5:1。
    static let greenDeep = Color(red: 0.055, green: 0.400, blue: 0.208)
    /// 行分隔线比 `lineSoft` 更轻——密集列表里分隔线不该抢视线。
    static let divider = Color(red: 0.933, green: 0.945, blue: 0.957)
}

/// 「减少动态效果」是系统级无障碍开关，悬停反馈要跟着它走。
private var reduceMotionEnabled: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

enum LogoAsset {
    static let image: NSImage = {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "vRemoterLogo", withExtension: "png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png")
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) { return image }
        }
        return NSImage(size: NSSize(width: 64, height: 64))
    }()
}

private enum GuideAsset {
    static func image(named name: String) -> NSImage? {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?
                .appendingPathComponent("PermissionGuides", isDirectory: true)
                .appendingPathComponent("\(name).png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/PermissionGuides/\(name).png")
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) { return image }
        }
        return nil
    }
}

enum RemoteImageAsset {
    static func image(for remote: SupportedRemoteID) -> NSImage? {
        let name = remote == .chromecast
            ? "chromecast-voice-remote"
            : "x6-remote"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?
                .appendingPathComponent("RemoteImages", isDirectory: true)
                .appendingPathComponent("\(name).png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/RemoteImages/\(name).png")
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) { return image }
        }
        return nil
    }
}

private enum ConsoleModal: Identifiable {
    case permission(PermissionKind)

    var id: String {
        switch self {
        case .permission(let kind): "permission-\(kind.id)"
        }
    }
}

private enum ConsolePage: String, CaseIterable, Identifiable {
    case mixer
    case mapping

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mixer: L10n.text("音频", "Audio")
        case .mapping: L10n.text("按键映射", "Key Mapping")
        }
    }

    var symbol: String {
        switch self {
        case .mixer: "slider.horizontal.3"
        case .mapping: "keyboard"
        }
    }
}

@MainActor
private final class ConsoleViewModel: ObservableObject {
    @Published var selectedPage: ConsolePage = CommandLine.arguments.contains(
        "--mapping-window-demo"
    ) ? .mapping : .mixer
    @Published var status = "启动中"
    @Published var hidConnected = false
    @Published var bleConnected = false
    @Published var remoteStreaming = false
    /// 遥控器音频通路是否开着（App 正在把遥控器采样写进虚拟声卡）。
    @Published var routeActive = false
    @Published var doubaoIsRecording = false
    @Published var doubaoInput = "--"
    @Published var driverAvailable = false
    @Published var remoteLevelDB = -120.0
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false
    @Published var bluetoothGranted = false
    @Published var x6Connected = false
    @Published var chromecastConnected = false
    @Published var inputTriggerKey = AppStorage.inputTriggerKey
    @Published var activeModal: ConsoleModal?
    @Published var showX6MicHint = !UserDefaults.standard.bool(
        forKey: "vRemoter.hasCompletedX6MicTest"
    )

    var onStopMicrophone: (() -> Void)?
    var onRestartApp: (() -> Void)?
    var onInputTriggerChanged: (() -> Void)?
    var onRemoteMappingEnabledChanged: ((SupportedRemoteID, Bool) -> Void)?

    var doubaoUsesVRemote: Bool { doubaoInput.contains("vRemoteDr 2ch") }

    func setInputTrigger(_ trigger: InputTriggerKey) {
        guard inputTriggerKey != trigger else { return }
        inputTriggerKey = trigger
        AppStorage.inputTriggerKey = trigger
        onInputTriggerChanged?()
    }

    func setRemoteMappingEnabled(_ enabled: Bool, remote: SupportedRemoteID) {
        RemoteMappingStore.shared.setEnabled(enabled, for: remote)
        onRemoteMappingEnabledChanged?(remote, enabled)
    }

    func refreshPermissions() {
        let demoMode = ProcessInfo.processInfo.environment["VREMOTER_PERMISSION_DEMO"] == "1"
            || CommandLine.arguments.contains("--permission-demo")
        if demoMode {
            accessibilityGranted = false
            inputMonitoringGranted = false
            bluetoothGranted = false
            return
        }
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
        if #available(macOS 11.0, *) {
            bluetoothGranted = CBManager.authorization == .allowedAlways
        } else {
            bluetoothGranted = true
        }
    }

    func openSettings(for kind: PermissionKind) {
        if kind == .doubaoInput {
            openDoubaoSettings()
            activeModal = nil
            return
        }
        guard let url = kind.settingsURL else { return }
        NSWorkspace.shared.open(url)
        activeModal = nil
    }

    private func openDoubaoSettings() {
        let bundleIdentifier = "com.bytedance.inputmethod.doubaoime.settings"
        let candidates = [
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
            URL(
                fileURLWithPath:
                    "/Library/Input Methods/DoubaoIme.app/Contents/DoubaoImeSettings.app"
            )
        ]
        for candidate in candidates.compactMap({ $0 })
            where FileManager.default.fileExists(atPath: candidate.path) {
            if NSWorkspace.shared.open(candidate) { return }
        }
    }

    func openSoundInputSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Sound-Settings.extension?input",
            "x-apple.systempreferences:com.apple.preference.sound?input"
        ]
        for value in candidates {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { break }
        }
    }

    func observeRemoteLevel(_ db: Double) {
        remoteLevelDB = db
        guard showX6MicHint, db > -100 else { return }
        UserDefaults.standard.set(true, forKey: "vRemoter.hasCompletedX6MicTest")
        showX6MicHint = false
    }

}

final class DebugWindowController: NSWindowController, NSWindowDelegate {
    private static let windowSize = NSSize(width: 775, height: 658)

    var onStopMicrophone: (() -> Void)?
    var onRestartApp: (() -> Void)?
    var onInputTriggerChanged: (() -> Void)?
    var onRemoteMappingEnabledChanged: ((SupportedRemoteID, Bool) -> Void)?

    private let model = ConsoleViewModel()
    private var permissionTimer: Timer?

    init() {
        let windowSize = Self.windowSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("vRemoter 控制台", "vRemoter Console")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(
            red: 0.965,
            green: 0.969,
            blue: 0.976,
            alpha: 1
        )
        window.appearance = NSAppearance(named: .aqua)
        window.minSize = windowSize
        window.maxSize = windowSize
        super.init(window: window)
        window.delegate = self

        model.onStopMicrophone = { [weak self] in self?.onStopMicrophone?() }
        model.onRestartApp = { [weak self] in self?.onRestartApp?() }
        model.onInputTriggerChanged = { [weak self] in
            self?.onInputTriggerChanged?()
        }
        model.onRemoteMappingEnabledChanged = { [weak self] remote, enabled in
            self?.onRemoteMappingEnabledChanged?(remote, enabled)
        }
        window.contentView = NSHostingView(
            rootView: StudioMixerView(model: model)
                .preferredColorScheme(.light)
                .frame(
                    width: windowSize.width,
                    height: windowSize.height
                )
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        model.refreshPermissions()
        startPermissionTimer()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func update(
        status: String,
        hidConnected: Bool,
        bleConnected: Bool,
        remoteStreaming: Bool,
        routeActive: Bool,
        doubaoIsRecording: Bool,
        doubaoInput: String,
        driverAvailable: Bool,
        x6Connected: Bool,
        chromecastConnected: Bool,
        remoteLevelDB: Double? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.model.status = status
            self.model.hidConnected = hidConnected
            self.model.bleConnected = bleConnected
            self.model.remoteStreaming = remoteStreaming
            self.model.routeActive = routeActive
            self.model.doubaoIsRecording = doubaoIsRecording
            self.model.doubaoInput = doubaoInput
            self.model.driverAvailable = driverAvailable
            self.model.x6Connected = x6Connected
            self.model.chromecastConnected = chromecastConnected
            if let remoteLevelDB { self.model.remoteLevelDB = remoteLevelDB }
            self.model.refreshPermissions()
        }
    }

    func updateRemoteLevel(_ db: Double) {
        DispatchQueue.main.async { [weak self] in self?.model.observeRemoteLevel(db) }
    }

    func windowWillClose(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func startPermissionTimer() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.model.refreshPermissions()
            }
        }
    }
}

private struct StudioMixerView: View {
    @ObservedObject var model: ConsoleViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 68)
            if model.selectedPage == .mixer {
                Spacer().frame(height: 15)
                mixer
                    .frame(height: 288)
                Spacer().frame(height: 17)
                statusPanel
                    .frame(height: 230)
            } else {
                Spacer().frame(height: 15)
                KeyMappingView(model: model)
                    .frame(height: 535)
            }
        }
        .padding(20)
        .frame(width: 775, height: 658)
        .background(ConsoleTheme.panel)
        .sheet(item: $model.activeModal) { modal in
            switch modal {
            case .permission(let kind):
                PermissionGuideView(
                    kind: kind,
                    onCancel: { model.activeModal = nil },
                    onOpenSettings: { model.openSettings(for: kind) }
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: LogoAsset.image)
                .resizable()
                .interpolation(.high)
                .frame(width: 45, height: 45)
            VStack(alignment: .leading, spacing: 1) {
                Text("vRemoter")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ConsoleTheme.text)
                Text(L10n.text("遥控器语音输入", "Remote microphone input"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConsoleTheme.secondary)
            }
            ConsolePageSelector(selection: $model.selectedPage)
                .frame(width: 202)
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                Text(model.remoteStreaming
                    ? L10n.text("录音中", "Recording")
                    : statusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            if model.remoteStreaming {
                Button(L10n.text("结束录音", "Stop")) { model.onStopMicrophone?() }
                    .buttonStyle(ConsoleButtonStyle(
                        tone: ConsoleButtonTone.error,
                        compact: true,
                        consoleSized: true
                    ))
            }
        }
        .padding(.horizontal, 20)
        .background(panelBackground(ConsoleTheme.surface, radius: 19))
    }

    private var statusText: String {
        if !model.accessibilityGranted || !model.inputMonitoringGranted {
            return L10n.text("需要处理", "Action needed")
        }
        if model.hidConnected && model.bleConnected {
            return L10n.text("正在运行", "Running")
        }
        return L10n.text("正在连接", "Connecting")
    }

    private var statusColor: Color {
        if model.remoteStreaming { return ConsoleTheme.amber }
        if !model.accessibilityGranted || !model.inputMonitoringGranted {
            return ConsoleTheme.red
        }
        return model.hidConnected && model.bleConnected
            ? ConsoleTheme.green
            : ConsoleTheme.amber
    }

    private var mixer: some View {
        HStack(spacing: 0) {
            AudioStageCard(
                title: L10n.text("遥控器麦克风", "Remote Mic"),
                subtitle: L10n.text("蓝牙语音遥控器", "Bluetooth Voice Remote"),
                stateText: remoteMicState.text,
                stateColor: remoteMicState.color,
                db: model.remoteLevelDB,
                meterColor: ConsoleTheme.green,
                showTestHint: model.showX6MicHint && model.hidConnected && model.bleConnected
            )
            PipelineArrow()
            AudioStageCard(
                title: L10n.text("虚拟声卡", "Virtual sound card"),
                subtitle: "vRemoteDr 2ch",
                stateText: virtualDeviceState.text,
                stateColor: virtualDeviceState.color,
                db: virtualDeviceLevelDB,
                meterColor: ConsoleTheme.amber
            )
            PipelineArrow()
            AudioStageCard(
                title: L10n.text("音频输出", "Audio Output"),
                subtitle: L10n.text("发送给豆包", "Sent to Doubao"),
                stateText: outputState.text,
                stateColor: outputState.color,
                db: doubaoLevelDB,
                meterColor: ConsoleTheme.amber
            )
        }
    }

    // 三段看的是同一路音频，区别在门控：左=遥控器回来的原始电平，
    // 中=真正写进虚拟声卡的电平（通路没开/驱动缺失时归零），
    // 右=豆包实际读到的电平（豆包没读它就归零）。一眼能看出断在哪一段。
    private var remoteMicState: (text: String, color: Color) {
        model.remoteLevelDB > -100
            ? (L10n.text("有声音", "Active"), ConsoleTheme.green)
            : (L10n.text("无声", "Silent"), ConsoleTheme.tertiary)
    }

    private var virtualDeviceState: (text: String, color: Color) {
        if !model.driverAvailable {
            return (L10n.text("未安装", "Not installed"), ConsoleTheme.red)
        }
        return model.routeActive
            ? (L10n.text("正在写入", "Writing"), ConsoleTheme.amber)
            : (L10n.text("空闲", "Idle"), ConsoleTheme.tertiary)
    }

    private var virtualDeviceLevelDB: Double {
        model.driverAvailable && model.routeActive ? model.remoteLevelDB : -120
    }

    private var outputState: (text: String, color: Color) {
        if !model.driverAvailable {
            return (L10n.text("未输出", "No output"), ConsoleTheme.red)
        }
        if model.doubaoIsRecording {
            return model.doubaoUsesVRemote
                ? (L10n.text("豆包正在接收", "Doubao is receiving"),
                   ConsoleTheme.amber)
                : (L10n.text("豆包没读它", "Doubao is not using it"),
                   ConsoleTheme.red)
        }
        return (L10n.text("等待录音", "Waiting"), ConsoleTheme.tertiary)
    }

    private var doubaoLevelDB: Double {
        model.doubaoIsRecording && model.doubaoUsesVRemote
            ? virtualDeviceLevelDB
            : -120
    }

    private var statusPanel: some View {
        VStack(spacing: 0) {
            StatusRow(
                title: L10n.text("豆包输入设备", "Doubao input"),
                value: model.doubaoIsRecording
                    ? (model.doubaoUsesVRemote
                        ? L10n.text("虚拟声卡 · 录音中",
                                    "Virtual sound card · Recording")
                        : model.doubaoInput)
                    : L10n.text("当前未录音", "Not recording"),
                tone: model.doubaoIsRecording && !model.doubaoUsesVRemote ? .error : .good,
                action: model.doubaoIsRecording && !model.doubaoUsesVRemote
                    ? L10n.text("设置方法", "Fix settings")
                    : nil,
                onAction: { model.activeModal = .permission(.doubaoInput) }
            )
            StatusRow(
                title: L10n.text("音频驱动", "Audio driver"),
                value: model.driverAvailable
                    ? L10n.text("虚拟声卡可用",
                                "Virtual sound card available")
                    : L10n.text("未安装或需要修复", "Missing or needs repair"),
                tone: model.driverAvailable ? .good : .error,
                action: model.driverAvailable ? nil : L10n.text("打开声音", "Open Sound"),
                onAction: model.openSoundInputSettings
            )
            StatusRow(
                title: L10n.text("遥控器连接", "Remote connection"),
                value: x6Value,
                tone: model.hidConnected && model.bleConnected ? .good : .warning,
                action: model.hidConnected && model.bleConnected
                    ? nil
                    : L10n.text("蓝牙设置", "Bluetooth settings"),
                onAction: { model.activeModal = .permission(.bluetooth) }
            )
            StatusRow(
                title: L10n.text("辅助功能权限", "Accessibility"),
                value: model.accessibilityGranted
                    ? L10n.text("已授权", "Granted")
                    : L10n.text("语音键无法正确映射", "Voice key mapping unavailable"),
                tone: model.accessibilityGranted ? .good : .error,
                action: model.accessibilityGranted ? nil : L10n.text("去授权", "Grant"),
                onAction: { model.activeModal = .permission(.accessibility) }
            )
            StatusRow(
                title: L10n.text("输入监控权限", "Input Monitoring"),
                value: model.inputMonitoringGranted
                    ? L10n.text("已授权", "Granted")
                    : L10n.text("无法监听遥控器语音键", "Cannot monitor remote voice key"),
                tone: model.inputMonitoringGranted ? .good : .warning,
                action: model.inputMonitoringGranted ? nil : L10n.text("去授权", "Grant"),
                onAction: { model.activeModal = .permission(.inputMonitoring) }
            )
        }
        .padding(.horizontal, 15)
        .background(panelBackground(ConsoleTheme.surface, radius: 19))
    }

    private var x6Value: String {
        if model.hidConnected && model.bleConnected {
            return model.remoteStreaming
                ? L10n.text("遥控器麦克风传输中", "Remote mic streaming")
                : L10n.text("遥控器麦克风已就绪", "Remote mic ready")
        }
        if model.hidConnected || model.bleConnected {
            return L10n.text("遥控器麦克风连接中", "Connecting remote mic")
        }
        return L10n.text("遥控器麦克风未连接", "Remote mic not connected")
    }
}

private struct ConsolePageSelector: View {
    @Binding var selection: ConsolePage

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ConsolePage.allCases) { page in
                Button {
                    selection = page
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: page.symbol)
                        Text(page.title)
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(
                        selection == page
                            ? ConsoleTheme.text
                            : ConsoleTheme.secondary
                    )
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(
                        selection == page
                            ? ConsoleTheme.surface2
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
            }
        }
        .padding(3)
        .background(ConsoleTheme.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct KeyMappingView: View {
    @ObservedObject var model: ConsoleViewModel
    @ObservedObject private var mappings = RemoteMappingStore.shared
    @State private var selectedDevice: SupportedRemoteID = .chromecast
    /// 当前被悬停的行（或图上被悬停的锚点）。只为这一条画连线——
    /// 15 条线常驻是这一页显乱的根源，而「查某个键对应哪行」本来就是逐个看的动作。
    @State private var hoveredButtonID: String?

    /// `previewHoverButtonID` 只服务 `--ui-snapshot`：把悬停态也渲染进静态图。
    /// 运行时是 nil，悬停一律由 `.onHover` 驱动。
    init(model: ConsoleViewModel, previewHoverButtonID: String? = nil) {
        self.model = model
        _hoveredButtonID = State(initialValue: previewHoverButtonID)
    }

    var body: some View {
        VStack(spacing: 12) {
            triggerPanel
                .frame(height: 100)
            mappingCard
        }
    }

    // MARK: - 映射卡：设备头部 + 三栏 + 脚注

    private var mappingCard: some View {
        VStack(spacing: 0) {
            cardHeader
            Rectangle()
                .fill(ConsoleTheme.divider)
                .frame(height: 0.5)
            GeometryReader { proxy in
                let layout = RemoteMappingLayout.layout(
                    remote: selectedDevice,
                    width: proxy.size.width,
                    imageAspect: imageAspect,
                    isActive: markerActive
                )
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: RemoteMappingLayout.columnGap) {
                        mappingColumn(layout.left)
                        centerColumn(width: layout.imageWidth)
                        mappingColumn(layout.right)
                    }
                    // 焦点标记在最上层：常态整个透明（静态不画任何东西），
                    // 悬停行或图上的热区时，只在对应按键上亮一圈。
                    Canvas { context, _ in
                        drawFocusMarker(context: context, layout: layout)
                    }
                    .allowsHitTesting(false)
                    anchorHitZones(layout)
                }
            }
            // 内边距必须加在 GeometryReader **外面**：这样里面拿到的才是收窄后
            // 的宽度，Canvas 的坐标才和三栏实际摆放的位置对齐。之前加在里面的
            // ZStack 上，Canvas 按未收窄的宽度算锚点，落点整体偏了 16pt。
            .padding(.top, 6)
            .padding(.horizontal, 16)
            cardFootnote
        }
        .background(panelBackground(ConsoleTheme.surface, radius: 17))
    }

    private var imageAspect: CGFloat {
        guard let image = RemoteImageAsset.image(for: selectedDevice),
              image.size.height > 0
        else { return 0.34 }
        return image.size.width / image.size.height
    }

    // MARK: - 焦点标记

    /// 悬停高亮：只在被悬停的按键上画「光晕 + 白心绿环」。
    /// 静态时什么都不画（用户要求：小圆点常态透明、连线全部去掉），
    /// 行↔按键的对应关系完全靠悬停这一下建立。
    /// 锚点坐标仍取自排版算好的折线终点，`RemoteMappingLayout` 不用改。
    private func drawFocusMarker(
        context: GraphicsContext,
        layout: RemoteMappingLayout.Layout
    ) {
        for line in layout.lines {
            guard line.buttonID == hoveredButtonID,
                  let end = line.points.last
            else { continue }

            let halo = Path(ellipseIn: CGRect(
                x: end.x - 11, y: end.y - 11, width: 22, height: 22
            ))
            context.fill(halo, with: .color(ConsoleTheme.green.opacity(0.13)))

            let ring = Path(ellipseIn: CGRect(
                x: end.x - 6, y: end.y - 6, width: 12, height: 12
            ))
            context.fill(ring, with: .color(ConsoleTheme.surface))
            context.stroke(ring, with: .color(ConsoleTheme.green), lineWidth: 2)
        }
    }

    /// 图上按键的悬停热区：鼠标移到按键上，对应的行跟着亮。
    /// 必须撑满整块区域，否则超出自身 frame 的热区收不到鼠标事件。
    /// 32pt 是按最挤的方向盘（上下两键中心距 28pt）取的：盖得住按键、
    /// 又尽量少跟旁边的热区抢事件。
    private func anchorHitZones(_ layout: RemoteMappingLayout.Layout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.lines, id: \.buttonID) { line in
                if let end = line.points.last {
                    Color.clear
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .offset(x: end.x - 16, y: end.y - 16)
                        .onHover { hovering in
                            setHover(hovering ? line.buttonID : nil)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 悬停是瞬时反馈：120ms 淡入足够，但「减少动态效果」打开时直接切换。
    private func setHover(_ id: String?) {
        guard hoveredButtonID != id else { return }
        if reduceMotionEnabled {
            hoveredButtonID = id
        } else {
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredButtonID = id
            }
        }
    }

    private var triggerPanel: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(L10n.text("豆包语音触发键", "Doubao voice trigger"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ConsoleTheme.text)
                } icon: {
                    Image(systemName: "waveform.badge.mic")
                        .foregroundStyle(ConsoleTheme.green)
                }
                Text(L10n.text(
                    "遥控器语音键与电脑键盘都使用这个按键控制豆包。这里必须与豆包输入法中的语音快捷键保持一致。",
                    "The remote voice key and Mac keyboard both use this trigger. It must match Doubao Input Method's voice shortcut."
                ))
                    .font(.system(size: 12))
                    .foregroundStyle(ConsoleTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 430, alignment: .leading)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                pillMenu(text: model.inputTriggerKey.title, width: 150) {
                    ForEach(InputTriggerKey.allCases) { trigger in
                        Button(trigger.title) { model.setInputTrigger(trigger) }
                    }
                }
                .disabled(model.remoteStreaming)
                if model.inputTriggerKey == .function {
                    Label(
                        L10n.text("Fn 需在本机测试", "Test Fn on this Mac"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ConsoleTheme.amber)
                } else if model.remoteStreaming {
                    Text(L10n.text("录音结束后可修改", "Stop recording to change"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(ConsoleTheme.tertiary)
                }
            }
        }
        .padding(.horizontal, 19)
        .background(panelBackground(ConsoleTheme.surface, radius: 17))
    }

    /// 「值 + chevron」的小胶囊。用来替掉系统下拉框——原生蓝底蓝箭头在这页会跟
    /// 语义绿打架，而这一页有十几个下拉，蓝色一多就没有强调色可言了。
    ///
    /// 外观必须画在 `Menu` **外面**：`Menu` 的 label 里只要出现 `Image`，SwiftUI
    /// 就按 LabelStyle 把它当图标挪到文字前面；label 自带的背景/描边也会被丢掉
    /// （实测，见 `--ui-controls-trial`）。所以这里的约定是「Menu 只管弹菜单，
    /// 胶囊和箭头都由外面画」。
    /// `width` 给了就把箭头推到最右，没给就紧贴文字（设备名长度不定）。
    private func pillMenu<Content: View>(
        text: String,
        width: CGFloat? = nil,
        @ViewBuilder menu: () -> Content
    ) -> some View {
        HStack(spacing: 6) {
            Menu(content: menu) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ConsoleTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            if width != nil {
                Spacer(minLength: 0)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(ConsoleTheme.tertiary)
        }
        .padding(.horizontal, 9)
        .frame(width: width, height: 24, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(ConsoleTheme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 7).stroke(ConsoleTheme.line, lineWidth: 0.5)
        )
    }

    // MARK: - 卡片头部（原设备条并进来）

    private var cardHeader: some View {
        HStack(spacing: 8) {
            deviceSelector

            Circle()
                .fill(deviceConnected ? ConsoleTheme.green : ConsoleTheme.tertiary)
                .frame(width: 6, height: 6)
            Text(deviceConnected
                ? L10n.text("已连接", "Connected")
                : L10n.text("未连接", "Offline"))
                .font(.system(size: 11))
                .foregroundStyle(ConsoleTheme.secondary)

            Spacer(minLength: 10)

            if !mappings.isEnabled(selectedDevice) {
                Label(
                    L10n.text("未启用时保持系统原行为", "System behavior is unchanged"),
                    systemImage: "info.circle"
                )
                .font(.system(size: 10.5))
                .foregroundStyle(ConsoleTheme.secondary)
            }
            Toggle(
                L10n.text("启用映射", "Enable"),
                isOn: Binding(
                    get: { mappings.isEnabled(selectedDevice) },
                    set: { model.setRemoteMappingEnabled($0, remote: selectedDevice) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            Rectangle()
                .fill(ConsoleTheme.divider)
                .frame(width: 0.5, height: 14)
            Button(L10n.text("恢复默认", "Reset")) {
                mappings.reset(selectedDevice)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(ConsoleTheme.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    /// 只暴露一个型号时显示静态名字（X6 暂时隐藏，见 `visibleCases`）；
    /// 将来恢复多型号支持，这里会自动变回下拉。
    @ViewBuilder
    private var deviceSelector: some View {
        if SupportedRemoteID.visibleCases.count > 1 {
            pillMenu(text: selectedDevice.title) {
                ForEach(SupportedRemoteID.visibleCases) { remote in
                    Button(remote.title) { selectedDevice = remote }
                }
            }
        } else {
            Text(selectedDevice.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ConsoleTheme.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 9)
                .frame(height: 24, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 7).fill(ConsoleTheme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(ConsoleTheme.line, lineWidth: 0.5)
                )
        }
    }

    private var cardFootnote: some View {
        Text(L10n.text(
            "悬停任意一行，或把鼠标移到图上的按键，两边会一起亮",
            "Hover a row or a button on the remote to link the two"
        ))
            .font(.system(size: 11))
            .foregroundStyle(ConsoleTheme.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
            .padding(.bottom, 10)
    }

    private var deviceConnected: Bool {
        selectedDevice == .chromecast ? model.chromecastConnected : model.x6Connected
    }

    // MARK: - 左中右三栏

    private func mappingColumn(_ rows: [RemoteMappingLayout.Row]) -> some View {
        VStack(spacing: RemoteMappingLayout.rowGap) {
            ForEach(Array(rows.enumerated()), id: \.element.button.id) { index, row in
                MappingRow(
                    remote: selectedDevice,
                    button: row.button,
                    enabled: mappings.isEnabled(selectedDevice),
                    isHighlighted: hoveredButtonID == row.button.id,
                    onHover: { hovering in
                        setHover(hovering ? row.button.id : nil)
                    }
                )
                .frame(height: RemoteMappingLayout.rowHeight)
                // 分隔线落在行顶部那 2pt 留白里，悬停胶囊不会把它盖掉。
                .overlay(alignment: .top) {
                    if index > 0 {
                        Rectangle()
                            .fill(ConsoleTheme.divider)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.top, RemoteMappingLayout.topInset)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func centerColumn(width: CGFloat) -> some View {
        Group {
            if let image = RemoteImageAsset.image(for: selectedDevice) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: RemoteMappingLayout.imageHeight)
            } else {
                Label(
                    L10n.text("遥控器图片缺失", "Remote image unavailable"),
                    systemImage: "photo.badge.exclamationmark"
                )
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(ConsoleTheme.secondary)
                .multilineTextAlignment(.center)
                .frame(
                    width: RemoteMappingLayout.centerColumnWidth,
                    height: RemoteMappingLayout.imageHeight
                )
            }
        }
        .frame(
            width: RemoteMappingLayout.centerColumnWidth,
            height: RemoteMappingLayout.imageHeight,
            alignment: .top
        )
    }

    /// 图上的点跟着映射状态走：这个键没被「禁用」就是实心，禁用/内部功能更淡。
    private func markerActive(_ button: RemoteButtonDefinition) -> Bool {
        guard button.remappable else { return false }
        if button.voiceControlled { return true }
        return mappings.target(for: button, remote: selectedDevice) != .disabled
    }
}

private struct MappingRow: View {
    @ObservedObject private var mappings = RemoteMappingStore.shared
    @State private var showRecorder = false
    let remote: SupportedRemoteID
    let button: RemoteButtonDefinition
    let enabled: Bool
    let isHighlighted: Bool
    let onHover: (Bool) -> Void

    /// 上下各留 2pt：悬停胶囊不贴到行分隔线上。
    private let verticalInset: CGFloat = 2

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: button.symbol)
                .font(.system(size: 11))
                .frame(width: 15)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(button.title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ConsoleTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(width: 76, alignment: .leading)
            Spacer(minLength: 8)
            valueArea
        }
        .padding(.horizontal, 10)
        .frame(height: RemoteMappingLayout.rowHeight - verticalInset * 2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHighlighted ? ConsoleTheme.goodDeep : Color.clear)
        )
        .padding(.vertical, verticalInset)
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        // 映射没启用时整行压暗：一眼看出「这些设置当前不生效」。
        .opacity(enabled ? 1 : 0.55)
        .sheet(isPresented: $showRecorder) {
            KeyboardShortcutCaptureView(
                buttonTitle: button.title,
                onCancel: { showRecorder = false },
                onSave: { shortcut in
                    mappings.setCustomShortcut(
                        shortcut,
                        for: button,
                        remote: remote
                    )
                    showRecorder = false
                }
            )
        }
    }

    @ViewBuilder
    private var valueArea: some View {
        if !button.remappable {
            Text(L10n.text("设备内部功能", "Device-only function"))
                .font(.system(size: 11.5))
                .foregroundStyle(ConsoleTheme.tertiary)
        } else if button.voiceControlled {
            Text(RemoteMappingTarget.doubaoVoice.title)
                .font(.system(size: 11.5, weight: isHighlighted ? .medium : .regular))
                .foregroundStyle(isHighlighted ? ConsoleTheme.greenDeep : ConsoleTheme.green)
        } else {
            HStack(spacing: 4) {
                targetMenu
                if currentTarget == .custom {
                    secondaryActionButton(
                        symbol: "record.circle",
                        help: L10n.text("重新录制按键", "Record again")
                    ) { showRecorder = true }
                } else if currentTarget == .openApp {
                    secondaryActionButton(
                        symbol: "app.badge",
                        help: L10n.text("重新选择应用", "Choose another app"),
                        action: chooseApp
                    )
                }
            }
        }
    }

    /// 「当前值 + chevron」的文字菜单：替掉系统下拉框，去掉那一片蓝色。
    /// 箭头同样画在 `Menu` 外面，理由见 `pillMenu`。
    private var targetMenu: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(RemoteMappingTarget.allCases.filter { $0 != .doubaoVoice }) { target in
                    // 只有「当前选中的那一项」显示动态名字（自定义按键的组合、所选 App
                    // 的名字）。其它项一律显示目标本身的名字，否则每一项都会显示成当前
                    // 目标的标题（曾导致列表里出现两个「禁用」、两个「系统音量＋」）。
                    Button(targetLabel(for: target)) { select(target) }
                }
            } label: {
                Text(mappings.targetTitle(for: button, remote: remote))
                    .font(.system(size: 11.5, weight: isHighlighted ? .medium : .regular))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(isHighlighted ? ConsoleTheme.greenDeep : ConsoleTheme.tertiary)
        }
        .accessibilityLabel(L10n.text("\(button.title) 的动作", "\(button.title) action"))
    }

    private func secondaryActionButton(
        symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHighlighted ? ConsoleTheme.greenDeep : ConsoleTheme.green)
        .help(help)
    }

    private func select(_ target: RemoteMappingTarget) {
        switch target {
        case .custom:
            showRecorder = true
        case .openApp:
            mappings.setTarget(target, for: button, remote: remote)
            chooseApp()
        default:
            mappings.setTarget(target, for: button, remote: remote)
        }
    }

    private var iconColor: Color {
        if isHighlighted { return ConsoleTheme.greenDeep }
        return button.voiceControlled ? ConsoleTheme.green : ConsoleTheme.secondary
    }

    /// 高亮行落在浅绿底上，绿色要换深一档才够 4.5:1（见 `greenDeep`）。
    private var valueColor: Color {
        if isHighlighted { return ConsoleTheme.greenDeep }
        return currentTarget == .disabled ? ConsoleTheme.tertiary : ConsoleTheme.secondary
    }

    private var currentTarget: RemoteMappingTarget {
        mappings.target(for: button, remote: remote)
    }

    private func targetLabel(for target: RemoteMappingTarget) -> String {
        target == currentTarget
            ? mappings.targetTitle(for: button, remote: remote)
            : target.title
    }

    /// 选一个 App 作为这个按键的动作。用「/应用程序」作为起始目录，
    /// 只允许选 .app。
    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = L10n.text("选择", "Choose")
        panel.message = L10n.text(
            "选择按下「\(button.title)」时要打开的 App",
            "Choose the app to open when \(button.title) is pressed"
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else {
            print("[MAPPING] ⚠️ 选中的不是可用的 App：\(url.path)")
            return
        }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        mappings.setAppMapping(
            RemoteAppMapping(bundleID: bundleID, name: name, path: url.path),
            for: button,
            remote: remote
        )
    }
}

private struct KeyboardShortcutCaptureView: View {
    let buttonTitle: String
    let onCancel: () -> Void
    let onSave: (RemoteCustomShortcut) -> Void
    @State private var captured: RemoteCustomShortcut?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("录制键盘按键", "Record Keyboard Key"))
                    .font(.system(size: 20, weight: .semibold))
                Text(L10n.text(
                    "为“\(buttonTitle)”按下一个按键或组合键。",
                    "Press a key or shortcut for “\(buttonTitle)”."
                ))
                    .font(.system(size: 13))
                    .foregroundStyle(ConsoleTheme.secondary)
            }

            KeyboardEventCaptureView { shortcut in
                captured = shortcut
            }
            .frame(height: 82)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        captured == nil ? ConsoleTheme.line : ConsoleTheme.green,
                        lineWidth: 1.5
                    )
            )
            .overlay {
                VStack(spacing: 5) {
                    Text(captured?.label ?? L10n.text("现在按下键盘按键", "Press a key now"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(captured == nil ? ConsoleTheme.secondary : ConsoleTheme.text)
                    Text(L10n.text("支持 Command / Option / Control / Shift 组合", "Command / Option / Control / Shift are supported"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(ConsoleTheme.tertiary)
                }
                .allowsHitTesting(false)
            }

            HStack {
                Button(L10n.text("取消", "Cancel"), action: onCancel)
                Spacer()
                Button(L10n.text("保存映射", "Save Mapping")) {
                    if let captured { onSave(captured) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(captured == nil)
            }
        }
        .padding(24)
        .frame(width: 430, height: 245)
        .background(ConsoleTheme.panel)
        .foregroundStyle(ConsoleTheme.text)
    }
}

private struct KeyboardEventCaptureView: NSViewRepresentable {
    let onCapture: (RemoteCustomShortcut) -> Void

    func makeNSView(context: Context) -> KeyboardCaptureNSView {
        let view = KeyboardCaptureNSView()
        view.onCapture = onCapture
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyboardCaptureNSView: NSView {
    var onCapture: ((RemoteCustomShortcut) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        onCapture?(Self.shortcut(from: event))
    }

    private static func shortcut(from event: NSEvent) -> RemoteCustomShortcut {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var flags: CGEventFlags = []
        var prefix = ""
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
            prefix += "⌃"
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
            prefix += "⌥"
        }
        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
            prefix += "⇧"
        }
        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
            prefix += "⌘"
        }

        let special: [UInt16: String] = [
            0x24: "Return", 0x30: "Tab", 0x31: "Space", 0x33: "Delete",
            0x35: "Esc", 0x73: "Home", 0x77: "End", 0x74: "Page Up",
            0x79: "Page Down", 0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        let key = special[event.keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? String(format: "Key 0x%02X", event.keyCode)
        return RemoteCustomShortcut(
            keyCode: event.keyCode,
            flags: flags.rawValue,
            label: prefix + key
        )
    }
}

/// 音频流水线上的一段。三段共用同一路音频，各自的门控值由调用方算好
/// （见 StudioMixerView 的 remoteMicState / virtualDeviceState / outputState）。
private struct AudioStageCard: View {
    let title: String
    let subtitle: String
    let stateText: String
    let stateColor: Color
    let db: Double
    let meterColor: Color
    var showTestHint = false

    // 控制台内容宽 735，去掉两条 20 的箭头列后每块约 231，左右各 18 内边距
    // 还剩约 195：12 格 × 12pt 加间距正好 188，既不挤也不空。
    private static let meterCount = 12
    private static let meterBarWidth: CGFloat = 12
    private static let meterWidth: CGFloat =
        CGFloat(meterCount) * meterBarWidth + CGFloat(meterCount - 1) * 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ConsoleTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(ConsoleTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 4)
            // 标题在上面、实时状态和电平贴着底部，中间留白——三段并排时
            // 视线正好落在下方那条电平带上。
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(stateText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(stateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(dbText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ConsoleTheme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 14)
            MeterView(
                db: db,
                color: meterColor,
                count: Self.meterCount,
                barWidth: Self.meterBarWidth
            )
            .padding(.top, showTestHint ? 34 : 16)
            .overlay(alignment: .topLeading) {
                if showTestHint {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                        Text(L10n.text(
                            "按一下遥控器麦克风键测试",
                            "Press the remote mic button"
                        ))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(ConsoleTheme.text)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(ConsoleTheme.black.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(ConsoleTheme.green.opacity(0.8), lineWidth: 1)
                    )
                    .offset(y: -1)
                }
            }
            HStack {
                Text(L10n.text("低", "Low"))
                Spacer()
                Text(L10n.text("高", "High"))
            }
            .font(.system(size: 10))
            .foregroundStyle(ConsoleTheme.tertiary)
            .frame(width: Self.meterWidth)
            .padding(.top, 6)
            Spacer().frame(height: 22)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground(ConsoleTheme.surface2, radius: 19))
    }

    private var dbText: String {
        guard db > -100 else { return "−∞" }
        return String(format: "%.0f dB", db)
    }
}

/// 两块之间表示音频流向的小箭头。
private struct PipelineArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ConsoleTheme.tertiary)
            .frame(width: 20)
            .frame(maxHeight: .infinity)
    }
}

private struct MeterView: View {
    let db: Double
    let color: Color
    let count: Int
    var barWidth: CGFloat = 13

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < activeCount ? color : ConsoleTheme.black)
                    .frame(width: barWidth, height: 21)
            }
        }
    }

    private var activeCount: Int {
        guard db > -100 else { return 0 }
        return min(count, max(0, Int(((db + 60) / 60) * Double(count))))
    }
}

private enum StatusTone { case good, warning, error }

private struct StatusPill: View {
    let title: String
    let tone: StatusTone

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 13)
        .frame(height: 28)
        .background(background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.9), lineWidth: 1))
    }

    private var color: Color {
        switch tone {
        case .good: ConsoleTheme.green
        case .warning: ConsoleTheme.amber
        case .error: ConsoleTheme.red
        }
    }

    private var background: Color {
        switch tone {
        case .good: ConsoleTheme.black
        case .warning: ConsoleTheme.amberDeep
        case .error: ConsoleTheme.redDeep
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let tone: StatusTone
    let action: String?
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ConsoleTheme.secondary)
                .frame(width: 145, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone == .good ? ConsoleTheme.text : color)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let action {
                Button(action, action: onAction)
                    .buttonStyle(ConsoleButtonStyle(
                        tone: tone,
                        compact: true,
                        consoleSized: true
                    ))
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 35)
        .background(tone == .good ? Color.clear : color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var color: Color {
        switch tone {
        case .good: ConsoleTheme.green
        case .warning: ConsoleTheme.amber
        case .error: ConsoleTheme.red
        }
    }
}

private struct PermissionGuideView: View {
    let kind: PermissionKind
    let onCancel: () -> Void
    let onOpenSettings: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(nsImage: LogoAsset.image)
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 19, weight: .semibold))
                    Text(L10n.text(
                        "设置向导 · 第 \(page + 1) / \(kind.pageCount) 步",
                        "Setup guide · Step \(page + 1) of \(kind.pageCount)"
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(ConsoleTheme.secondary)
                }
                Spacer()
            }

            GuideScreenshot(kind: kind, page: $page)
                .frame(height: 350)

            Text(kind.guidance[page])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ConsoleTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<kind.pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? ConsoleTheme.green : ConsoleTheme.line)
                            .frame(width: index == page ? 18 : 7, height: 7)
                    }
                }
                Spacer()
                Button(L10n.text("取消", "Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(ConsoleButtonStyle(tone: .neutral))
                Button(L10n.text("立即设置", "Open Settings"), action: onOpenSettings)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(ConsoleButtonStyle(tone: ConsoleButtonTone.good))
            }
        }
        .padding(22)
        .frame(width: 620, height: 580)
        .background(ConsoleTheme.panel)
        .foregroundStyle(ConsoleTheme.text)
    }
}

private struct GuideScreenshot: View {
    let kind: PermissionKind
    @Binding var page: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = GuideAsset.image(named: kind.screenshotName(for: page)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    screenshotPlaceholder
                }

                if kind != .doubaoInput || page == 0 {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ConsoleTheme.red, lineWidth: 3)
                        .frame(
                            width: proxy.size.width * highlightWidth,
                            height: proxy.size.height * highlightHeight
                        )
                        .position(
                            x: proxy.size.width * highlightX,
                            y: proxy.size.height * highlightY
                        )
                }

                HStack {
                    guideArrow(systemName: "chevron.left", enabled: page > 0) {
                        if page > 0 { page -= 1 }
                    }
                    Spacer()
                    guideArrow(systemName: "chevron.right", enabled: page < kind.pageCount - 1) {
                        if page < kind.pageCount - 1 { page += 1 }
                    }
                }
                .padding(.horizontal, 10)
            }
            .background(ConsoleTheme.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ConsoleTheme.line))
        }
    }

    private var screenshotPlaceholder: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("系统设置", "System Settings"))
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.text("隐私与安全性", "Privacy & Security"))
                    .foregroundStyle(ConsoleTheme.text)
                Text(kind.title.replacingOccurrences(of: "权限", with: ""))
                    .foregroundStyle(ConsoleTheme.green)
                Spacer()
            }
            .padding(20)
            .frame(width: 190, alignment: .leading)
            .background(ConsoleTheme.surface)
            VStack(alignment: .leading, spacing: 18) {
                Text(kind.title)
                    .font(.system(size: 18, weight: .semibold))
                Text(L10n.text(
                    "允许下方的应用访问此功能。",
                    "Allow the apps below to access this feature."
                ))
                    .foregroundStyle(ConsoleTheme.secondary)
                HStack {
                    Image(nsImage: LogoAsset.image).resizable().frame(width: 30, height: 30)
                    Text("vRemoter")
                    Spacer()
                    Toggle("", isOn: .constant(false)).labelsHidden()
                }
                .padding(12)
                .background(ConsoleTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                Spacer()
            }
            .padding(20)
        }
        .foregroundStyle(ConsoleTheme.text)
    }

    private var secondPageY: CGFloat {
        switch kind {
        case .doubaoInput: 0.5
        case .accessibility: 0.89
        case .inputMonitoring: 0.46
        case .bluetooth: 0.74
        }
    }

    private var highlightWidth: CGFloat {
        kind == .doubaoInput ? 0.36 : (page == 0 ? 0.38 : 0.45)
    }

    private var highlightHeight: CGFloat {
        kind == .doubaoInput ? 0.11 : 0.10
    }

    private var highlightX: CGFloat {
        kind == .doubaoInput ? 0.60 : (page == 0 ? 0.255 : 0.62)
    }

    private var highlightY: CGFloat {
        kind == .doubaoInput ? 0.40 : (page == 0 ? 0.25 : secondPageY)
    }

    private func guideArrow(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(ConsoleTheme.black.opacity(0.82))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? ConsoleTheme.text : ConsoleTheme.tertiary)
        .disabled(!enabled)
    }

}

private enum ConsoleButtonTone { case neutral, good, warning, error }

private struct ConsoleButtonStyle: ButtonStyle {
    let tone: ConsoleButtonTone
    var compact = false
    var consoleSized = false

    init(tone: ConsoleButtonTone, compact: Bool = false, consoleSized: Bool = false) {
        self.tone = tone
        self.compact = compact
        self.consoleSized = consoleSized
    }

    init(tone: StatusTone, compact: Bool = false, consoleSized: Bool = false) {
        switch tone {
        case .good: self.tone = .good
        case .warning: self.tone = .warning
        case .error: self.tone = .error
        }
        self.compact = compact
        self.consoleSized = consoleSized
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(height: buttonHeight)
            .background(configuration.isPressed ? background.opacity(0.65) : background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(foreground.opacity(0.85), lineWidth: 1)
            )
    }

    private var fontSize: CGFloat {
        if consoleSized { return compact ? 11 : 14 }
        return compact ? 9 : 11
    }

    private var horizontalPadding: CGFloat {
        if consoleSized { return compact ? 15 : 23 }
        return compact ? 12 : 18
    }

    private var buttonHeight: CGFloat {
        if consoleSized { return compact ? 30 : 43 }
        return compact ? 24 : 34
    }

    private var cornerRadius: CGFloat {
        if consoleSized { return compact ? 12 : 11 }
        return compact ? 10 : 9
    }

    private var foreground: Color {
        switch tone {
        case .neutral: ConsoleTheme.text
        case .good: ConsoleTheme.green
        case .warning: ConsoleTheme.amber
        case .error: ConsoleTheme.red
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: ConsoleTheme.black
        case .good: ConsoleTheme.goodDeep
        case .warning: ConsoleTheme.amberDeep
        case .error: ConsoleTheme.redDeep
        }
    }
}

private func panelBackground(_ color: Color, radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius)
        .fill(color)
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(ConsoleTheme.line, lineWidth: 1))
}

#if DEBUG
/// 把控制台界面离线渲染成 PNG，用来在改完界面后自查外观。
///
/// 为什么不用 `screencapture`：那需要「屏幕录制」权限，而 App 渲染自己的视图
/// 不需要——也不会把窗口弹到别人屏幕上。
///
/// 用法：`.build/debug/vRemote --ui-snapshot <输出目录>`
@MainActor
enum UISnapshot {
    private static let pageSize = CGSize(width: 775, height: 658)

    /// `main.swift` 的顶层代码不是 MainActor，所以这个判断要 nonisolated。
    nonisolated static var isRequested: Bool {
        CommandLine.arguments.contains("--ui-snapshot")
    }

    static func runIfRequested() -> Int32? {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--ui-snapshot") else { return nil }
        guard flag + 1 < arguments.count else {
            FileHandle.standardError.write(
                Data("用法：--ui-snapshot <输出目录>\n".utf8)
            )
            return EXIT_FAILURE
        }
        let directory = arguments[flag + 1]

        func makeModel() -> ConsoleViewModel {
            let model = ConsoleViewModel()
            model.selectedPage = .mapping
            // 快照里让设备显示「已连接」，否则状态点和文案是离线态，看不出真实样子。
            model.chromecastConnected = true
            model.hidConnected = true
            model.bleConnected = true
            return model
        }

        capture(
            StudioMixerView(model: makeModel()),
            named: "映射页-默认态.png",
            to: directory
        )
        // 悬停态单独出一张：焦点标记只有 hover 时才画，静态默认态看不到。
        capture(
            KeyMappingView(model: makeModel(), previewHoverButtonID: "07")
                .frame(width: pageSize.width - 40, height: pageSize.height - 40)
                .padding(20)
                .background(ConsoleTheme.panel),
            named: "映射页-悬停确认键.png",
            to: directory
        )
        // 电源键是新补的锚点（机身底部 ⏻），单独出一张便于核对落点。
        capture(
            KeyMappingView(model: makeModel(), previewHoverButtonID: "01")
                .frame(width: pageSize.width - 40, height: pageSize.height - 40)
                .padding(20)
                .background(ConsoleTheme.panel),
            named: "映射页-悬停电源键.png",
            to: directory
        )
        return EXIT_SUCCESS
    }

    private static func capture<V: View>(_ view: V, named name: String, to directory: String) {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: pageSize)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()

        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pageSize.width * scale),
            pixelsHigh: Int(pageSize.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            FileHandle.standardError.write(Data("快照失败：无法创建位图\n".utf8))
            return
        }
        rep.size = pageSize
        host.cacheDisplay(in: host.bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("快照失败：PNG 编码失败\n".utf8))
            return
        }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
        do {
            try data.write(to: url)
            FileHandle.standardOutput.write(Data("快照：\(url.path)\n".utf8))
        } catch {
            FileHandle.standardError.write(
                Data("快照失败：\(error.localizedDescription)\n".utf8)
            )
        }
    }
}
#endif
