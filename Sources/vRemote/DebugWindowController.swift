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
                    "不要选“自动检测”。实测它不会跟随「遥控说」切换，往往一直用内置麦克风，而且选上之后短按关不掉录音。",
                    "Do not choose Automatic Detection. Measured behaviour: it does not follow Saymote, tends to keep using the built-in microphone, and once selected a short press cannot stop recording."
                )
            ]
        case .accessibility:
            return [
                L10n.text(
                    "系统设置会打开到“隐私与安全性 → 辅助功能”。",
                    "System Settings will open Privacy & Security > Accessibility."
                ),
                L10n.text(
                    "找到「遥控说」并打开开关。列表中没有时，点加号选择应用。",
                    "Enable Saymote. If it is missing, use the plus button to add the app."
                )
            ]
        case .inputMonitoring:
            return [
                L10n.text(
                    "系统设置会打开到“隐私与安全性 → 输入监控”。",
                    "System Settings will open Privacy & Security > Input Monitoring."
                ),
                L10n.text(
                    "找到「遥控说」并打开开关。macOS 提示重新启动时允许它重新打开。",
                    "Enable Saymote, then allow macOS to relaunch it when prompted."
                )
            ]
        case .bluetooth:
            return [
                L10n.text(
                    "系统设置会打开到“隐私与安全性 → 蓝牙”。",
                    "System Settings will open Privacy & Security > Bluetooth."
                ),
                L10n.text(
                    "找到「遥控说」并打开开关，然后返回应用等待遥控器重新连接。",
                    "Enable Saymote, then return to the app and wait for the remote to reconnect."
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
            // 从仓库直接跑（未打包）时的回退路径。
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Design/Saymote-Logo/saymote-logo-256.png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Design/Saymote-Logo/saymote-app-icon-1024.png")
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) { return image }
        }
        return NSImage(size: NSSize(width: 64, height: 64))
    }()
}

/// 菜单栏图标。用「template」版本（纯剪影 + `isTemplate = true`），
/// macOS 会按菜单栏明暗自动反色；彩色图标在深色菜单栏上会糊成一团。
///
/// 图片直接内嵌 base64：菜单栏图标必须随 App 一起分发，内嵌就不依赖打包脚本
/// 有没有拷到资源目录（这个项目已经被打包漏文件坑过一次）。
enum StatusIconAsset {
    static let image: NSImage = {
        // 逻辑尺寸统一给 16pt：16px 那张是 1x、32px 那张是 2x（NSImage 按
        // 「像素宽 ÷ 逻辑宽」推断倍率）。之前把 32px 那张的逻辑尺寸也设成 32pt，
        // 倍率会被当成 1，Retina 下就会取错图。
        let image = NSImage(size: NSSize(width: 16, height: 16))
        for base64 in [template1x, template2x] {
            guard let data = Data(
                base64Encoded: base64,
                options: .ignoreUnknownCharacters
            ), let rep = NSBitmapImageRep(data: data)
            else { continue }
            rep.size = NSSize(width: 16, height: 16)
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        return image
    }()

    private static let template1x = """
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA
    xUlEQVQ4jZ2RwQnCQBREXwziTcGDdpBTMFiCFShoVYIFiBWINuFJDHiwAsESgiAIGlkYYQlLdpMP
    j/kMf4aFBfdE0p6wvaCJpAdg36agD4yBHDgDI2AQEoyla+BhFdyBTeWmtmALPIErcAEKYBdSEEkn
    wAyYApn2rHLjLUmAuUhCwx1pqmeXopBn3zgnli4VvIlSnn1TW7BSKBWlvMYFR9G64CNaF7xF44KF
    Ql9hduN5C/7/PAROwEuY3Xj2jXe6ChnM7pwfV4Iv0IkE+a8AAAAASUVORK5CYII=
    """

    private static let template2x = """
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAsTAAALEwEAmpwYAAAB
    xUlEQVRYhd2XzytEURTHP2/elI2dyMKC/AFKKQp/wWTByr/gP7AeCREKZSzV/A1SNiwo2aEUK2Vr
    oamZwXsafV+dbsav7rvKqdM579xzOp95957pPvi9RG38oNIpDSoF2RHgAbgHhp21XJt3yF8BUumi
    Yh15QkTSWM9rBmBZsaLJ8968Jf3AzLsHqwZgSbFpYEC+N4hItgu4UcMt/eoMYAFYl38L9PiEKMiO
    Aq9qcgFsG4AN4Ex+Aow7tV4AxoCmmpwDOwZgEziV/wxMqCb2CTAENNTkWPueAZSBI/nNPMeyDFwB
    U0AvcAgcAN1ACbg0I5mbFMyoFT54zlXiL062/Z/wLpFsn7aiCuxLq4r1Obnem/cC1zps2Uha/1o5
    3iGKsvNqVNdprzt+qhxb40Vi2V0z64l5A4liqXJsjVeAimn4qH0vy8+AKiEAUmDOrM+ZeDCAklkv
    hQLYM41OgEHpiYnvhQB4NtNQd2LBAJI2UxD0DSQG5E8AUqNBACrfAKj8S4CicxVvmP3PNLstrTk1
    XiSWnQRezAG0U5BqbdKp8SaR7CxwB9SAJ2lNsVkn17tEsq1PsNbd32r2yZb7l/Jn974f3wnfAOB8
    vGMgKCDBAAAAAElFTkSuQmCC
    """
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
        case .mixer: L10n.text("系统设置", "System Settings")
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
    /// 「系统设置」模块里的语言与登录启动。真值来源分别是 AppLanguage 与
    /// LaunchAtLogin，这里只是镜像；refreshPermissions() 会定期校正回来。
    @Published var language = AppLanguage.selected
    @Published var launchAtLogin = LaunchAtLogin.isEnabled

    var onStopMicrophone: (() -> Void)?
    var onRestartApp: (() -> Void)?
    var onInputTriggerChanged: (() -> Void)?
    var onRemoteMappingEnabledChanged: ((SupportedRemoteID, Bool) -> Void)?
    var onLanguageChanged: ((AppLanguage) -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    var doubaoUsesVRemote: Bool { doubaoInput.contains("vRemoteDr 2ch") }

    /// 切换语言：交给 App 层写盘并重启（和菜单栏里那条一样）。
    func setLanguage(_ value: AppLanguage) {
        guard value != language else { return }
        language = value
        onLanguageChanged?(value)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard enabled != launchAtLogin else { return }
        launchAtLogin = enabled
        onLaunchAtLoginChanged?(enabled)
    }

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
        // 语言 / 登录启动也可能从菜单栏那边改，顺手校正一遍。
        launchAtLogin = LaunchAtLogin.isEnabled
        language = AppLanguage.selected
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
    var onLanguageChanged: ((AppLanguage) -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

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
        window.title = L10n.text("遥控说 控制台", "Saymote Console")
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
        model.onLanguageChanged = { [weak self] language in
            self?.onLanguageChanged?(language)
        }
        model.onLaunchAtLoginChanged = { [weak self] enabled in
            self?.onLaunchAtLoginChanged?(enabled)
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
                // 两个模块都按内容高度排、行距固定（行间那点空档不摊开），
                // 剩下的零头留在页面底部，不掺进行距里。
                Spacer().frame(height: 16)
                ConsoleSectionHeader(title: L10n.text("系统状态", "System Status"))
                Spacer().frame(height: 8)
                mixer
                    .frame(height: 185)
                Spacer().frame(height: 20)
                ConsoleSectionHeader(title: L10n.text("系统设置", "System Settings"))
                Spacer().frame(height: 8)
                settingsPanel
                Spacer(minLength: 0)
            } else {
                Spacer().frame(height: 15)
                KeyMappingView(model: model)
                    .frame(height: 512)
                Spacer(minLength: 0)
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
                Text("遥控说")
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
        // 录音中是「一切正常」的状态，统一用绿色；只有真出问题才转红。
        if model.remoteStreaming { return ConsoleTheme.green }
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
                meterColor: ConsoleTheme.green
            )
            PipelineArrow()
            AudioStageCard(
                title: L10n.text("音频输出", "Audio Output"),
                subtitle: L10n.text("发送给豆包", "Sent to Doubao"),
                stateText: outputState.text,
                stateColor: outputState.color,
                db: doubaoLevelDB,
                meterColor: ConsoleTheme.green
            )
        }
    }

    // 三段看的是同一路音频，区别在门控：左=遥控器回来的原始电平，
    // 中=真正写进虚拟声卡的电平（通路没开/驱动缺失时归零），
    // 右=豆包实际读到的电平（豆包没读它就归零）。一眼能看出断在哪一段。
    //
    // 颜色约定：只要在录音，三段的波形和状态一律绿色、状态文字统一叫「录音中」；
    // 只有真出故障（驱动缺失、豆包没读虚拟声卡）才用红色。
    private var remoteMicState: (text: String, color: Color) {
        if model.remoteStreaming {
            return (L10n.text("录音中", "Recording"), ConsoleTheme.green)
        }
        return model.remoteLevelDB > -100
            ? (L10n.text("有声音", "Active"), ConsoleTheme.green)
            : (L10n.text("无声", "Silent"), ConsoleTheme.tertiary)
    }

    private var virtualDeviceState: (text: String, color: Color) {
        if !model.driverAvailable {
            return (L10n.text("未安装", "Not installed"), ConsoleTheme.red)
        }
        return model.routeActive
            ? (L10n.text("录音中", "Recording"), ConsoleTheme.green)
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
                ? (L10n.text("录音中", "Recording"), ConsoleTheme.green)
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

    /// 「系统设置」模块：上面几行是状态/权限（只读，出问题给修复入口），
    /// 下面两行是可交互的设置（语言、登录时自动启动）。
    private var settingsPanel: some View {
        VStack(spacing: 6) {
            statusRows
            ConsoleConfigRow(title: L10n.text("语言", "Language")) {
                ConsolePillMenu(
                    text: languageTitle,
                    width: 150,
                    items: AppLanguage.allCases.map { language in
                        MappingMenuItem(
                            title: title(for: language),
                            checked: language == model.language
                        )
                    },
                    onSelect: { index in
                        model.setLanguage(AppLanguage.allCases[index])
                    }
                )
                .help(L10n.text("切换语言后会重启 App", "Changing language restarts the app"))
            }
            ConsoleConfigRow(title: L10n.text("登录时自动启动", "Launch at login")) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 18)
        .background(panelBackground(ConsoleTheme.surface, radius: 19))
    }

    /// 状态 / 权限五行（只读，出问题给修复入口）。单独抽一层，
    /// 免得 ViewBuilder 一层堆超过 10 个子视图。行间用 Spacer 均分空档。
    @ViewBuilder
    private var statusRows: some View {
        VStack(spacing: 6) {
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
    }

    private var languageTitle: String {
        title(for: model.language)
    }

    private func title(for language: AppLanguage) -> String {
        switch language {
        case .system: L10n.text("跟随系统", "System Default")
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
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
    /// 当前被悬停的行（或图上被悬停的按键）。行和图上按键共用这一个状态，
    /// 两边就自动联动。线已全部去掉，对应关系全靠它建立。
    @State private var hoveredButtonID: String?
    /// 图上跟踪器最近报上来的键，离开时要拿它判断「该不该清」。
    @State private var lastTrackedID: String?

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
                    anchorHoverTracker(layout)
                }
            }
            // 内边距必须加在 GeometryReader **外面**：这样里面拿到的才是收窄后
            // 的宽度，Canvas 的坐标才和三栏实际摆放的位置对齐。之前加在里面的
            // ZStack 上，Canvas 按未收窄的宽度算锚点，落点整体偏了 16pt。
            .padding(.top, 6)
            .padding(.horizontal, 16)
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

    /// 图上的鼠标跟踪：交给 AppKit 拿真实坐标，再算「离哪个锚点最近」。
    ///
    /// 为什么不用一排 `onHover` 热区：方向盘五个键中心只隔 28pt，方块热区必然
    /// 互相重叠，重叠处谁在上面谁抢到事件，跟「指哪亮哪」的直觉对不上；热区做小
    /// 了又会出现「鼠标在上头也不亮」。按最近距离判定没有这些问题，半径也能给大。
    ///
    /// 这个 NSView 只监听鼠标移动，`hitTest` 返回 nil，绝不挡底下行的点击。
    private func anchorHoverTracker(_ layout: RemoteMappingLayout.Layout) -> some View {
        let columnLeft = layout.imageOriginX
            - (RemoteMappingLayout.centerColumnWidth - layout.imageWidth) / 2
        return AnchorHoverTracker(
            lines: layout.lines,
            offsetX: columnLeft,
            maxDistance: 44,
            onNearest: handleTrackedHover
        )
        .frame(
            width: RemoteMappingLayout.centerColumnWidth,
            height: RemoteMappingLayout.imageHeight,
            alignment: .topLeading
        )
        .offset(x: columnLeft)
    }

    /// 图上跟出来的高亮。离开时只清「自己刚报的那个键」——鼠标从图上划回行的
    /// 瞬间，行那边可能已经先设好了高亮，这里不能把它抹掉。
    private func handleTrackedHover(_ id: String?) {
        let previous = lastTrackedID
        lastTrackedID = id
        Log.write("[MAP-HOVER] 图上跟踪 → \(id ?? "无")")
        guard let id else {
            if let previous { clearHover(previous) }
            return
        }
        setHover(id)
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

    /// 只有「主动离开的那个键现在还是当前高亮」时才清空。
    /// 鼠标快速从 A 划到 B 时，B 的进入事件可能先到，如果 A 的离开事件无条件
    /// 清空，B 的高亮就被抹掉了——「划过不变色」就是这么来的。
    private func clearHover(_ id: String) {
        guard hoveredButtonID == id else { return }
        setHover(nil)
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
                pillMenu(
                    text: model.inputTriggerKey.title,
                    width: 150,
                    items: InputTriggerKey.allCases.map {
                        MappingMenuItem(
                            title: $0.title,
                            checked: $0 == model.inputTriggerKey
                        )
                    },
                    onSelect: { index in
                        model.setInputTrigger(InputTriggerKey.allCases[index])
                    }
                )
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
    private func pillMenu(
        text: String,
        width: CGFloat,
        items: [MappingMenuItem],
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        ConsolePillMenu(text: text, width: width, items: items, onSelect: onSelect)
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
            pillMenu(
                text: selectedDevice.title,
                width: 190,
                items: SupportedRemoteID.visibleCases.map {
                    MappingMenuItem(title: $0.title, checked: $0 == selectedDevice)
                },
                onSelect: { index in
                    selectedDevice = SupportedRemoteID.visibleCases[index]
                }
            )
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
                        // 进入就点亮；离开只清「自己这一条」，见 clearHover。
                        if hovering {
                            setHover(row.button.id)
                        } else {
                            clearHover(row.button.id)
                        }
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

/// 图上按键的鼠标跟踪。用一个 AppKit 视图拿真实鼠标坐标，算出「离哪个锚点最近」，
/// 绕开 SwiftUI 热区重叠抢事件的问题（方向盘五个键只隔 28pt）。
///
/// 它只监听鼠标移动：`hitTest` 返回 nil，所以不会挡住底下任何点击。
private struct AnchorHoverTracker: NSViewRepresentable {
    let lines: [RemoteMappingLayout.Line]
    /// 跟踪器只盖中间那一栏，换算回排版坐标要加回这个偏移。
    let offsetX: CGFloat
    let maxDistance: CGFloat
    let onNearest: (String?) -> Void

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.apply(lines: lines, offsetX: offsetX, maxDistance: maxDistance, onNearest: onNearest)
        return view
    }

    func updateNSView(_ view: TrackerView, context: Context) {
        view.apply(lines: lines, offsetX: offsetX, maxDistance: maxDistance, onNearest: onNearest)
    }

    final class TrackerView: NSView {
        private var lines: [RemoteMappingLayout.Line] = []
        private var offsetX: CGFloat = 0
        private var maxDistance: CGFloat = 44
        private var onNearest: ((String?) -> Void)?
        private var lastReported: String?

        /// 和 SwiftUI 一样用左上原点，省得每次换算 y。
        override var isFlipped: Bool { true }

        /// 绝不参与命中测试：鼠标事件靠跟踪区拿，点击照旧穿过去。
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func apply(
            lines: [RemoteMappingLayout.Line],
            offsetX: CGFloat,
            maxDistance: CGFloat,
            onNearest: ((String?) -> Void)?
        ) {
            self.lines = lines
            self.offsetX = offsetX
            self.maxDistance = maxDistance
            self.onNearest = onNearest
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // 跟踪区里的 .mouseMoved 要窗口愿意派发移动事件才收得到。
            window?.acceptsMouseMovedEvents = true
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas {
                removeTrackingArea(area)
            }
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseMoved,
                    .mouseEnteredAndExited,
                    .activeInKeyWindow,
                    .inVisibleRect
                ],
                owner: self,
                userInfo: nil
            ))
        }

        override func mouseMoved(with event: NSEvent) {
            report(event)
        }

        override func mouseDragged(with event: NSEvent) {
            report(event)
        }

        override func mouseExited(with event: NSEvent) {
            report(resolved: nil)
        }

        private func report(_ event: NSEvent) {
            let local = convert(event.locationInWindow, from: nil)
            let resolved = RemoteMappingLayout.nearestButtonID(
                to: CGPoint(x: local.x + offsetX, y: local.y),
                lines: lines,
                maxDistance: maxDistance
            )
            report(resolved: resolved)
        }

        /// 只在「判定结果变了」时上报：鼠标每挪一像素都回调没有意义，
        /// 也会让上层状态无谓地抖。
        private func report(resolved: String?) {
            guard resolved != lastReported else { return }
            lastReported = resolved
            onNearest?(resolved)
        }
    }
}

/// 下拉里的一个条目。
private struct MappingMenuItem {
    let title: String
    let checked: Bool
}

/// 「整块区域可点」的下拉。
///
/// 为什么不用 SwiftUI 的 `Menu`（实测过三件事）：
/// 1. label 里放 `Image` 会被 LabelStyle 当图标挪到文字**前面**；
/// 2. label 里放**第二个** `Text` 直接不渲染；
/// 3. label 只按自身理想宽度贴在左边，`maxWidth: .infinity` 也撑不开——
///    所以「热区和悬停变绿的范围一样大」用 `Menu` 做不到（用户反馈下拉不好点）。
///
/// 改成一个普通 Button 铺满整行/整块胶囊，点击时自己弹 `NSMenu`：
/// 热区就是 Button 的 label 范围，完全可控，label 里也能自由摆图标、文字和箭头。
private struct MappingMenuRow<Label: View>: View {
    let items: [MappingMenuItem]
    let onSelect: (Int) -> Void
    let label: Label

    @State private var actionTarget = MenuActionTarget()

    init(
        items: [MappingMenuItem],
        onSelect: @escaping (Int) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.items = items
        self.onSelect = onSelect
        self.label = label()
    }

    var body: some View {
        Button {
            present()
        } label: {
            label.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func present() {
        actionTarget.handler = onSelect
        let menu = NSMenu()
        for (index, item) in items.enumerated() {
            let entry = NSMenuItem(
                title: item.title,
                action: #selector(MenuActionTarget.fire(_:)),
                keyEquivalent: ""
            )
            entry.tag = index
            entry.target = actionTarget
            entry.state = item.checked ? .on : .off
            menu.addItem(entry)
        }
        // 在鼠标位置弹出，但整体下移一行的高度：这样菜单不会正好压在鼠标下面
        // （否则松手可能直接选中光标底下那一项）。靠近窗口底部时 AppKit 会自动
        // 翻到上方去。
        let mouse = NSEvent.mouseLocation
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: mouse.x - 12, y: mouse.y - 26),
            in: nil
        )
    }

    /// `NSMenu` 的 target：把选中的行号回调出去。
    final class MenuActionTarget: NSObject {
        var handler: ((Int) -> Void)?

        @objc func fire(_ sender: NSMenuItem) {
            handler?(sender.tag)
        }
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
        HStack(spacing: 6) {
            // 可改的行：整行都是菜单的 label，点击热区和「悬停变绿的范围」一样大
            // （用户反馈下拉不好点）。尾部的小按钮放在 Menu 外面，保留自己的小热区。
            rowMain
            if button.remappable, !button.voiceControlled, currentTarget == .custom {
                secondaryActionButton(
                    symbol: "record.circle",
                    help: L10n.text("重新录制按键", "Record again")
                ) { showRecorder = true }
            } else if button.remappable, !button.voiceControlled, currentTarget == .openApp {
                secondaryActionButton(
                    symbol: "app.badge",
                    help: L10n.text("重新选择应用", "Choose another app"),
                    action: chooseApp
                )
            }
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

    /// 可改的行：整行都是下拉的热区（和悬停变绿的范围一样大）。
    @ViewBuilder
    private var rowMain: some View {
        if button.remappable, !button.voiceControlled {
            MappingMenuRow(
                items: mappingMenuItems,
                onSelect: { index in select(mappingMenuTargets[index]) }
            ) {
                rowLabel(editable: true)
            }
        } else {
            rowLabel(editable: false)
        }
    }

    /// 下拉里列出的目标（语音键的目标是固定的，不列进来）。
    private var mappingMenuTargets: [RemoteMappingTarget] {
        RemoteMappingTarget.allCases.filter { $0 != .doubaoVoice }
    }

    private var mappingMenuItems: [MappingMenuItem] {
        let current = currentTarget
        return mappingMenuTargets.map { target in
            // 只有「当前选中的那一项」显示动态名字（自定义按键的组合、所选 App 的
            // 名字）。其它项一律显示目标本身的名字，否则每一项都会显示成当前目标
            // 的标题（曾导致列表里出现两个「禁用」、两个「系统音量＋」）。
            MappingMenuItem(
                title: targetLabel(for: target),
                checked: target == current
            )
        }
    }

    /// 行的内容：图标 + 名称 +（可改时）右侧的值与箭头。
    private func rowLabel(editable: Bool) -> some View {
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
            if !button.remappable {
                Text(L10n.text("设备内部功能", "Device-only function"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(ConsoleTheme.tertiary)
            } else if button.voiceControlled {
                Text(RemoteMappingTarget.doubaoVoice.title)
                    .font(.system(size: 11.5, weight: isHighlighted ? .medium : .regular))
                    .foregroundStyle(
                        isHighlighted ? ConsoleTheme.greenDeep : ConsoleTheme.green
                    )
            } else {
                Text(mappings.targetTitle(for: button, remote: remote))
                    .font(.system(size: 11.5, weight: isHighlighted ? .medium : .regular))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(
                        isHighlighted ? ConsoleTheme.greenDeep : ConsoleTheme.tertiary
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            // 标题 → 状态 → 波形 挨着排：之前中间用一个可伸缩 Spacer，卡片一高就
            // 留出一大片空档（用户反馈「标题和波形中间空太大」）。现在中段是固定
            // 间距，卡片比内容高出来的部分全落到最下面。
            Spacer().frame(height: 20)
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
            MeterView(
                db: db,
                color: meterColor,
                count: Self.meterCount,
                barWidth: Self.meterBarWidth
            )
            .padding(.top, showTestHint ? 34 : 14)
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
            // 卡片比内容高出来的部分全部收到这里。
            Spacer(minLength: 12)
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

/// 页面里的小节标题（「系统状态」「系统设置」）。
private struct ConsoleSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ConsoleTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 设置面板里「左边标签 + 右边控件」的一行。和 `StatusRow` 等高、标签列对齐
/// （前面留一个和状态圆点同宽的空位），两段混排时不会参差。
private struct ConsoleConfigRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ConsoleTheme.secondary)
                .frame(width: 145, alignment: .leading)
            content
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 13)
        .frame(height: 32)
    }
}

/// 「值 + 箭头」的小胶囊下拉。外观画在 `MappingMenuRow` 的 label 里（不是 SwiftUI
/// 的 `Menu`——原因见 `MappingMenuRow` 的注释），整块胶囊都是热区。
private struct ConsolePillMenu: View {
    let text: String
    let width: CGFloat
    let items: [MappingMenuItem]
    let onSelect: (Int) -> Void

    var body: some View {
        MappingMenuRow(items: items, onSelect: onSelect) {
            HStack(spacing: 6) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ConsoleTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
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
        .frame(height: 32)
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
                    Text("遥控说")
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

        func makeModel(_ page: ConsolePage = .mapping) -> ConsoleViewModel {
            let model = ConsoleViewModel()
            model.selectedPage = page
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
        capture(
            StudioMixerView(model: makeModel(.mixer)),
            named: "音频页-默认态.png",
            to: directory
        )
        // 伪造一个「正在录音」的状态，用来核对绿色波形和「录音中」文案
        // （真实电平要靠遥控器送音频，静态快照看不到）。
        let recording = makeModel(.mixer)
        recording.driverAvailable = true
        recording.routeActive = true
        recording.remoteStreaming = true
        recording.remoteLevelDB = -24
        recording.doubaoIsRecording = true
        recording.doubaoInput = "vRemoteDr 2ch"
        capture(
            StudioMixerView(model: recording),
            named: "音频页-录音中.png",
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
