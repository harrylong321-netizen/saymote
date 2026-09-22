// vRemote for macOS.
//
// 1. Supported remote voice key → matching Option toggle semantics
// 2. Remote ATVV voice data → vRemoteDr 2ch (界面里叫「虚拟声卡」) → Doubao
// 3. A physical Mac Option key controls the same remote microphone session
//
// macOS-only. Requires:
//   * X6-Remote or Chromecast Remote paired in System Settings → Bluetooth
//   * Accessibility permission (System Settings → Privacy & Security →
//     Accessibility) for Option observation and Search suppression
//   * vRemoteDriver.driver installed and visible as vRemoteDr 2ch（界面显示「虚拟声卡」）in
//     System Settings → Sound → Input/Output
//   * Doubao IME configured for Option-as-voice-mode trigger
//
// Run:   swift run
// Quit:  menu bar icon → 退出, or Ctrl+C

import AppKit
import CoreGraphics
import Darwin
import Foundation

// MARK: - Menu bar UI

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var headerLabel: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var loggingToggleItem: NSMenuItem!
    private var logSizeItem: NSMenuItem!
    private var languageItems: [AppLanguage: NSMenuItem] = [:]

    private var x6HIDConnected = false
    private var x6BLEConnected = false
    private var x6RemoteStreaming = false
    private var chromecastHIDConnected = false
    private var chromecastBLEConnected = false
    private var chromecastRemoteStreaming = false
    private var remoteStreaming = false

    private var lastVoiceRemote: VoiceRemoteID?
    /// 已经弹过提示的告警序号，避免同一告警重复弹浮层。
    private var lastShownWarningSerial = 0

    private let x6 = X6HIDBridge()
    private let chromecastHID = ChromecastRemoteHIDBridge()
    private let x6SearchSuppressor = X6SearchSuppressor()
    private let doubaoAudioState = DoubaoAudioStateMonitor()
    private lazy var x6Session = X6SessionCoordinator(
        doubaoState: doubaoAudioState
    )
    private let debugWindow = DebugWindowController()
    private let updateWindow = UpdateWindowController()
    private let x6BLE = BLEBridge(
        nameHint: "X6-Remote",
        savedUUIDFilename: "x6-uuid.txt",
        logTag: "X6-BLE",
        resetSessionOnConnect: true
    )
    private let chromecastBLE = BLEBridge(
        nameHint: "Chromecast Remote",
        savedUUIDFilename: "chromecast-remote-uuid.txt",
        logTag: "CAST-BLE",
        resetSessionOnConnect: true
    )

    /// 自动重启时传给新实例的参数：告诉它「你是来接替某个 pid 的」。
    private static let replacingArgument = "--replacing="

    /// 权限自检（诊断用，不影响正常流程）：
    ///   /Applications/遥控说.app/Contents/MacOS/vRemote --permission-probe
    /// 必须用**装好的**那个 .app 里的可执行文件跑，TCC 认的是它自己的签名。
    private func printPermissionProbe() {
        // 走 FileHandle：`exit()` 不会 flush stdio 缓冲，print 的内容会丢。
        var lines: [String] = []
        lines.append("[PROBE] bundle              = \(Bundle.main.bundlePath)")
        lines.append("[PROBE] AXIsProcessTrusted  = \(AXIsProcessTrusted())")
        lines.append("[PROBE] CGPreflightListen   = \(CGPreflightListenEventAccess())")
        lines.append("[PROBE] IOHIDCheck(listen)  = \(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue)")
        lines.append("[PROBE] IOHIDCheck(post)    = \(IOHIDCheckAccess(kIOHIDRequestTypePostEvent).rawValue)")
        // 申请接口的返回值：true = 系统认为已授权（可能只是被辅助功能涵盖）
        lines.append("[PROBE] IOHIDRequest(listen) = \(IOHIDRequestAccess(kIOHIDRequestTypeListenEvent))")
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    /// 首次启动主动「申请」一次输入监控。
    ///
    /// 系统只会把**申请过**的 App 列进「输入监听」列表，而且申请必须在
    /// 辅助功能授权之前发生才有效：一旦辅助功能已授权，系统认为输入监听
    /// 已被涵盖，既不提示也不再登记（这也是它一直显示「已授权」的由来）。
    private func requestInputMonitoringOnce() {
        // 按「版本」记一次：换版本再问一次，用户拒绝后也不会每次启动都弹。
        let key = "vRemoter.listenEventRequestedVersion"
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "?"
        guard UserDefaults.standard.string(forKey: key) != version else { return }
        UserDefaults.standard.set(version, forKey: key)
        // 两个申请接口都调：
        //   CGRequestListenEventAccess 会在系统里「登记」本 App 并弹提示
        //     （这正是「输入监听」列表里出现本 App 的前提）；
        //   IOHIDRequestAccess 与 App 实际使用的 IOHIDManager 同源。
        // 用 print：App 启动后 stdout 已被重定向到日志文件，FileHandle 写会丢。
        let cg = CGRequestListenEventAccess()
        let hid = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        print("[APP] 申请输入监控权限：CG=\(cg) IOHID=\(hid)")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--permission-probe") {
            printPermissionProbe()
            exit(0)
        }
        requestInputMonitoringOnce()
        // 单实例保护：`open -n` 可以强开第二个实例（安装脚本、自动重启都用它），
        // 两个实例会同时抢蓝牙和虚拟声卡——实测出现过两个进程交叉写同一份日志、
        // 抢设备。这里让后启动的那个自己退出，并把先启动的激活到前面。
        enforceSingleInstance()
        NSApp.setActivationPolicy(.accessory)
        AppStorage.prepare()
        AppAnalytics.configure()
        // Keep one continuous diagnostic history while X6 is being tuned.
        // Log.swift rotates at 5 MB; only the explicit menu action clears it.
        Log.setEnabled(true)
        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        print("[APP] ===== 遥控说 \(appVersion) started =====")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 菜单栏用剪影 template 图标（会随明暗自动反色），Dock/应用图标用彩色版本。
        statusItem.button?.image = StatusIconAsset.image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.title = ""
        // 左键单击直接开控制台，右键（含触控板双指点按）才弹菜单。
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.cell?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        NSApp.applicationIconImage = LogoAsset.image

        let menu = NSMenu()
        menu.delegate = self
        let header = NSMenuItem(
            title: L10n.text("状态 · 启动中", "Status · Starting"),
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        headerLabel = header

        let launch = NSMenuItem(
            title: L10n.text("登录时自动启动", "Launch at login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launch.target = self
        menu.addItem(launch)
        launchAtLoginItem = launch

        menu.addItem(.separator())
        menu.addItem(makeLogMenu())
        menu.addItem(makeLanguageMenu())

        // 「版本与更新」暂时屏蔽（用户要求，2026-09-22）：菜单入口和启动时的
        // 自动检查都关掉。UpdateSupport.swift 的实现与 `openVersionUpdates`
        // 都留着，恢复时把这段菜单项放回来即可。
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: L10n.text("退出", "Quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        // 注意：这里**不设置** statusItem.menu。一旦设了，按钮的点击就会被
        // 菜单接管，我们自己的 action 收不到事件。菜单改由 statusItemClicked
        // 在右键时手动弹出。
        statusMenu = menu
        refreshMenuState()
        wireDebugWindow()

        // X6 HID observation and ATVV audio are independent connections.
        x6.onConnectionChanged = { [weak self] connected in
            self?.x6HIDConnected = connected
            AppAnalytics.signal(
                connected ? "Remote.HID.connected" : "Remote.HID.disconnected"
            )
            self?.updateStatus()
        }
        // X6 does not emit a dependable HID edge on its first short press.
        // HID remains observation/search-suppression only; immediate voice
        // session control comes from AUDIO_START/AUDIO_STOP below.
        x6.onShortPress = { [weak self] in
            self?.x6Session.remoteHIDShortPress()
        }
        x6.onLongPressEnded = { [weak self] in
            self?.x6Session.remoteHIDLongPressEnded()
        }
        x6.onNativeSearchEdge = { [weak self] in
            self?.x6SearchSuppressor.arm()
        }
        x6SearchSuppressor.onTriggerDownObserved = { [weak self] synthetic in
            self?.x6Session.triggerDownObserved(isSynthetic: synthetic)
        }
        x6SearchSuppressor.onTriggerUpObserved = { [weak self] synthetic in
            self?.x6Session.triggerUpObserved(isSynthetic: synthetic)
        }
        x6BLE.onConnectionChanged = { [weak self] connected in
            self?.x6BLEConnected = connected
            AppAnalytics.signal(
                connected ? "Remote.BLE.connected" : "Remote.BLE.disconnected"
            )
            if !connected {
                self?.x6RemoteStreaming = false
                self?.x6Session.remoteDisconnected(.x6)
            }
            self?.refreshCombinedStreaming()
            self?.updateStatus()
        }
        x6BLE.onStreamingChanged = { [weak self] streaming, _ in
            self?.x6RemoteStreaming = streaming
            AppAnalytics.signal(streaming ? "Voice.started" : "Voice.stopped")
            self?.refreshCombinedStreaming()
            self?.updateStatus()
        }
        x6BLE.onAudioStarted = { [weak self] reason, _ in
            self?.lastVoiceRemote = .x6
            self?.x6Session.remoteAudioStarted(
                remote: .x6,
                reason: reason
            )
        }
        x6BLE.onAudioStopped = { [weak self] reason in
            self?.x6Session.remoteAudioStopped(remote: .x6, reason: reason)
        }
        x6BLE.onMicrophoneOpenFailed = { [weak self] code in
            self?.x6Session.remoteMicrophoneOpenFailed(
                remote: .x6,
                code: code
            )
        }
        x6BLE.onLevel = { [weak self] db, _ in
            self?.debugWindow.updateRemoteLevel(db)
        }
        chromecastHID.onConnectionChanged = { [weak self] connected in
            self?.chromecastHIDConnected = connected
            AppAnalytics.signal(
                connected
                    ? "Remote.Chromecast.HID.connected"
                    : "Remote.Chromecast.HID.disconnected"
            )
            self?.updateStatus()
        }
        chromecastBLE.onConnectionChanged = { [weak self] connected in
            self?.chromecastBLEConnected = connected
            AppAnalytics.signal(
                connected
                    ? "Remote.Chromecast.BLE.connected"
                    : "Remote.Chromecast.BLE.disconnected"
            )
            if !connected {
                self?.chromecastRemoteStreaming = false
                self?.x6Session.remoteDisconnected(.chromecast)
            }
            self?.refreshCombinedStreaming()
            self?.updateStatus()
        }
        chromecastBLE.onStreamingChanged = { [weak self] streaming, _ in
            self?.chromecastRemoteStreaming = streaming
            AppAnalytics.signal(
                streaming
                    ? "Voice.Chromecast.started"
                    : "Voice.Chromecast.stopped"
            )
            self?.refreshCombinedStreaming()
            self?.updateStatus()
        }
        chromecastBLE.onAudioStarted = { [weak self] reason, _ in
            self?.lastVoiceRemote = .chromecast
            self?.x6Session.remoteAudioStarted(
                remote: .chromecast,
                reason: reason,
                supportsPhysicalHoldGesture: true
            )
        }
        chromecastBLE.onAudioStopped = { [weak self] reason in
            self?.x6Session.remoteAudioStopped(
                remote: .chromecast,
                reason: reason
            )
        }
        chromecastBLE.onMicrophoneOpenFailed = { [weak self] code in
            self?.x6Session.remoteMicrophoneOpenFailed(
                remote: .chromecast,
                code: code
            )
        }
        chromecastBLE.onLevel = { [weak self] db, _ in
            self?.debugWindow.updateRemoteLevel(db)
        }
        x6Session.preferredRemoteProvider = { [weak self] in
            self?.preferredVoiceRemote()
        }
        x6Session.onMicrophoneCloseRequested = { [weak self] in
            self?.closeAllRemoteMicrophones()
        }
        x6Session.onMicrophoneOpenRequested = {
            [weak self] remote, bypassDebounce in
            return self?.openRemoteMicrophone(
                remote,
                bypassDebounce: bypassDebounce
            ) ?? .unavailable
        }
        x6Session.onStateChanged = { [weak self] status in
            self?.headerLabel.title = "状态 · \(status)"
            self?.updateStatus()
        }
        x6Session.start()
        x6SearchSuppressor.start()
        x6.start()
        x6BLE.start()
        chromecastHID.start()
        chromecastBLE.start()

        // Start the loopback engine eagerly so device binding is verified
        // before the first BLE audio packet arrives.
        _ = AudioPipe.shared
        AudioPipe.shared.onRouteChanged = { [weak self] _ in
            self?.updateStatus()
        }
        AudioPipe.shared.onRemoteAudioArrived = { [weak self] in
            self?.x6Session.remoteAudioObserved()
        }

        DispatchQueue.main.async { [weak self] in
            self?.debugWindow.show()
        }
        if CommandLine.arguments.contains("--update-available-demo") {
            print("[UPDATE] update-available demo requested")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateWindow.showDemoUpdate()
            }
        } else if CommandLine.arguments.contains("--update-current-demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateWindow.showUpToDateDemo()
            }
        } else if CommandLine.arguments.contains("--updates-window-demo") {
            print("[UPDATE] updates-window demo requested")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateWindow.show()
            }
        }
        // 原本这里还有一段「启动 8 秒后自动检查更新」的 else 分支，随
        // 「版本与更新」一起屏蔽。恢复时重新加回来。
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }

    private func makeLogMenu() -> NSMenuItem {
        let root = NSMenuItem(title: L10n.text("日志", "Logs"), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.text("日志", "Logs"))

        let toggle = NSMenuItem(
            title: L10n.text("记录日志", "Record logs"),
            action: #selector(toggleLogging),
            keyEquivalent: ""
        )
        toggle.target = self
        submenu.addItem(toggle)
        loggingToggleItem = toggle

        let size = NSMenuItem(title: L10n.text("占用 · 0 字节", "Size · 0 bytes"), action: nil, keyEquivalent: "")
        size.isEnabled = false
        submenu.addItem(size)
        logSizeItem = size

        let refresh = NSMenuItem(
            title: L10n.text("刷新占用大小", "Refresh size"),
            action: #selector(refreshStorageSizes),
            keyEquivalent: ""
        )
        refresh.target = self
        submenu.addItem(refresh)

        let open = NSMenuItem(
            title: L10n.text("打开日志文件夹", "Open logs folder"),
            action: #selector(openLogFolder),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let clear = NSMenuItem(
            title: L10n.text("清空日志", "Clear logs"),
            action: #selector(clearLog),
            keyEquivalent: ""
        )
        clear.target = self
        submenu.addItem(clear)

        root.submenu = submenu
        return root
    }

    private func makeLanguageMenu() -> NSMenuItem {
        let root = NSMenuItem(
            title: L10n.text("语言", "Language"),
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: L10n.text("语言", "Language"))
        let options: [(AppLanguage, String, Selector)] = [
            (.system, L10n.text("跟随系统", "System Default"), #selector(selectSystemLanguage)),
            (.simplifiedChinese, "简体中文", #selector(selectSimplifiedChinese)),
            (.english, "English", #selector(selectEnglish))
        ]
        for (language, title, selector) in options {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            item.state = AppLanguage.selected == language ? .on : .off
            submenu.addItem(item)
            languageItems[language] = item
        }
        root.submenu = submenu
        return root
    }

    private var warnedDoubaoInputDevice = false

    /// 豆包在录音，但用的不是我们的虚拟声卡——这时候遥控器说什么它都收不到，
    /// 用户体感就是「按了没反应」。弹一次提示并引导去改输入设备（每次录音
    /// 期间只提醒一次，避免刷屏）。
    private func warnDoubaoWrongInputDevice(actual: String) {
        guard !warnedDoubaoInputDevice else { return }
        warnedDoubaoInputDevice = true
        ToastPresenter.shared.show(
            L10n.text(
                "豆包正在用「\(actual)」，收不到遥控器的声音。请在豆包语音输入里把麦克风切成「虚拟声卡」。",
                "Doubao is using \(actual) and cannot hear the remote. Switch its microphone to the Virtual sound card."
            ),
            symbolName: "mic.slash.fill"
        )
    }

    private func updateStatus() {
        let anyHID = x6HIDConnected || chromecastHIDConnected
        let anyBLE = x6BLEConnected || chromecastBLEConnected
        let doubaoSnapshot = doubaoAudioState.snapshotNow()
        let doubaoUsesVRemote = doubaoSnapshot.inputDeviceNames.contains("vRemoteDr 2ch")
        let doubaoIsRecording = Self.doubaoIsRecording(doubaoSnapshot)
        let statusText: String
        if let warning = x6Session.audioWarningText {
            statusText = warning
        } else if doubaoIsRecording && !doubaoUsesVRemote {
            statusText = L10n.text("豆包输入设备错误", "Incorrect Doubao input")
            warnDoubaoWrongInputDevice(actual: doubaoSnapshot.deviceSummary)
        } else if remoteStreaming {
            statusText = L10n.text("遥控器录音中", "Remote recording")
            warnedDoubaoInputDevice = false
        } else if anyHID && anyBLE {
            statusText = L10n.text("已就绪", "Ready")
        } else if anyHID || anyBLE {
            statusText = L10n.text("正在连接语音服务", "Connecting voice service")
        } else {
            statusText = L10n.text("等待遥控器", "Waiting for remote")
        }
        statusItem.button?.toolTip = "遥控说 · \(statusText)"
        headerLabel.title = L10n.text("状态 · \(statusText)", "Status · \(statusText)")
        presentToastIfNeeded()
        debugWindow.update(
            status: statusText,
            hidConnected: anyHID,
            bleConnected: anyBLE,
            remoteStreaming: remoteStreaming,
            routeActive: AudioPipe.shared.isRemoteRouteActive,
            doubaoIsRecording: doubaoIsRecording,
            doubaoInput: doubaoSnapshot.deviceSummary,
            driverAvailable: AudioPipe.shared.isOutputDeviceAvailable,
            x6Connected: x6HIDConnected || x6BLEConnected,
            chromecastConnected: chromecastHIDConnected || chromecastBLEConnected,
            remoteLevelDB: nil
        )
    }

    /// 豆包是否正在录音。macOS 12/13 读不到 `kAudioProcessPropertyIsRunningInput`
    /// （14.2 才公开），`Snapshot.isRecording` 在旧系统上恒为 false，只能看
    /// 输入设备列表：豆包占着某个输入设备就等于它在录（见 `work/改动总览.md` 坑 4）。
    /// 会话逻辑 `trustedDoubaoRecording()` 用的就是这个口径，界面必须跟它一致，
    /// 否则旧系统上状态行永远是「当前未录音」。
    private static func doubaoIsRecording(
        _ snapshot: DoubaoAudioStateMonitor.Snapshot
    ) -> Bool {
        snapshot.isRecording || snapshot.hasInputDevice
    }

    /// 「遥控器未开麦」这类告警用屏幕下方的浮层提示——菜单栏在窗口多的时候
    /// 根本看不见。用序号判断是不是一条新告警，避免重复弹出。
    private func presentToastIfNeeded() {
        let serial = x6Session.audioWarningSerial
        guard serial != lastShownWarningSerial else { return }
        lastShownWarningSerial = serial
        guard let text = x6Session.audioWarningText else { return }
        ToastPresenter.shared.show(text)
    }

    private func wireDebugWindow() {
        debugWindow.onStopMicrophone = { [weak self] in
            self?.stopMicrophoneNow()
        }
        debugWindow.onRestartApp = { [weak self] in
            self?.restartAppNow()
        }
        debugWindow.onInputTriggerChanged = { [weak self] in
            self?.x6SearchSuppressor.triggerConfigurationDidChange()
        }
        debugWindow.onRemoteMappingEnabledChanged = { [weak self] remote, enabled in
            switch remote {
            case .x6:
                self?.x6.setRemappingEnabled(enabled)
            case .chromecast:
                self?.chromecastHID.setRemappingEnabled(enabled)
            }
        }
        // 「系统设置」模块里的两项：都复用菜单栏那套逻辑，保证两边行为一致。
        debugWindow.onLanguageChanged = { [weak self] language in
            self?.setLanguageAndRestart(language)
        }
        debugWindow.onPermissionGranted = { [weak self] in
            self?.restartForNewPermission()
        }
        debugWindow.onLaunchAtLoginChanged = { [weak self] enabled in
            guard let self else { return }
            do {
                try LaunchAtLogin.setEnabled(enabled)
            } catch {
                self.headerLabel.title = L10n.text(
                    "状态 · 登录启动设置失败",
                    "Status · Launch-at-login failed"
                )
            }
            // 让菜单里的勾选跟上；写失败时控制台那边的定时刷新会把开关拨回来。
            self.refreshMenuState()
        }
    }

    /// 状态栏图标：左键单击 → 直接打开控制台；右键单击（触控板双指点按，
    /// 或 Control+左键）→ 弹出下拉菜单。
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        guard isSecondary, let button = statusItem.button else {
            debugWindow.show()
            return
        }
        refreshMenuState()
        statusMenu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func openVersionUpdates() {
        updateWindow.show()
    }

    @objc private func selectSystemLanguage() {
        setLanguageAndRestart(.system)
    }

    @objc private func selectSimplifiedChinese() {
        setLanguageAndRestart(.simplifiedChinese)
    }

    @objc private func selectEnglish() {
        setLanguageAndRestart(.english)
    }

    private func setLanguageAndRestart(_ language: AppLanguage) {
        guard AppLanguage.selected != language else { return }
        AppLanguage.selected = language
        restartAppNow()
    }

    @objc private func stopMicrophone() {
        stopMicrophoneNow()
    }

    private func stopMicrophoneNow() {
        x6Session.forceClose()
        x6BLE.closeMicrophone(force: true)
        chromecastBLE.closeMicrophone(force: true)
        AudioPipe.shared.setRemoteActive(false)
        updateStatus()
    }

    @objc private func restartApp() {
        restartAppNow()
    }

    private var permissionRestartCount = 0
    private var lastPermissionRestartAt: Date?

    /// 检测到权限刚被打开 → 自动重启一次，让蓝牙 / 输入监控真正生效。
    ///
    /// 为什么必须重启：macOS 的蓝牙授权、输入监控授权都要**重启进程**才生效
    /// （系统自己也会提示「退出并重新打开」）。之前不重启的话，用户打完勾界面
    /// 上仍显示异常，得等遥控器再发一次广播才恢复——那条路太绕。
    /// 防抖 3 秒、每次启动最多 3 次，避免用户连续勾选时反复重启；
    /// 正在录音时不打断。
    private func restartForNewPermission() {
        guard permissionRestartCount < 3 else { return }
        guard !remoteStreaming else { return }
        let now = Date()
        if let last = lastPermissionRestartAt, now.timeIntervalSince(last) < 3 {
            return
        }
        lastPermissionRestartAt = now
        permissionRestartCount += 1
        print("[APP] 权限刚被授予 → 重启应用使其生效")
        ToastPresenter.shared.show(
            L10n.text("权限已开启，正在重启应用…", "Permission granted — restarting…"),
            symbolName: "checkmark.circle.fill"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.restartAppNow()
        }
    }

    /// 单实例保护（见 `applicationDidFinishLaunching` 里的调用处注释）。
    private func enforceSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        // 自己换代时不把自己拦掉：等旧实例退出（最多 3 秒），赖着不走就收掉它。
        if let raw = CommandLine.arguments.first(where: {
            $0.hasPrefix(Self.replacingArgument)
        }), let oldPID = pid_t(raw.dropFirst(Self.replacingArgument.count)),
           oldPID != myPID {
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline,
                  let old = NSRunningApplication(processIdentifier: oldPID),
                  !old.isTerminated {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if let old = NSRunningApplication(processIdentifier: oldPID),
               !old.isTerminated {
                old.forceTerminate()
            }
        }
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID && !$0.isTerminated }
        guard let keeper = others.min(by: { $0.processIdentifier < $1.processIdentifier })
        else { return }
        print("[APP] 已有实例在运行（pid=\(keeper.processIdentifier)），本次启动退出")
        keeper.activate(options: [.activateIgnoringOtherApps])
        exit(0)
    }

    private func restartAppNow() {
        stopMicrophoneNow()
        let bundleURL = Bundle.main.bundleURL
        // `NSWorkspace.openApplication` may reuse the current instance for an
        // accessory app. Use `/usr/bin/open -n` so macOS creates a genuinely
        // new process before this one exits. 带上 --replacing 让新实例知道
        // 「旧的那个是我，等我退出」，避免被单实例保护误杀。
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launcher.arguments = [
            "-n", bundleURL.path,
            "--args", Self.replacingArgument + "\(ProcessInfo.processInfo.processIdentifier)"
        ]
        do {
            try launcher.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NSApp.terminate(nil)
            }
        } catch {
            print("[APP] 重启失败: \(error.localizedDescription)")
        }
    }

    private func refreshCombinedStreaming() {
        remoteStreaming = x6RemoteStreaming || chromecastRemoteStreaming
    }

    private func preferredVoiceRemote() -> VoiceRemoteID? {
        if let lastVoiceRemote {
            switch lastVoiceRemote {
            case .x6 where x6BLEConnected:
                return .x6
            case .chromecast where chromecastBLEConnected:
                return .chromecast
            default:
                break
            }
        }
        if x6BLEConnected { return .x6 }
        if chromecastBLEConnected { return .chromecast }
        return nil
    }

    private func openRemoteMicrophone(
        _ remote: VoiceRemoteID,
        bypassDebounce: Bool
    ) -> RemoteMicrophoneOpenResult {
        switch remote {
        case .x6:
            guard x6BLEConnected else { return .unavailable }
            return x6BLE.openMicrophone(bypassDebounce: bypassDebounce)
        case .chromecast:
            guard chromecastBLEConnected else { return .unavailable }
            return chromecastBLE.openMicrophone(
                bypassDebounce: bypassDebounce
            )
        }
    }

    private func closeAllRemoteMicrophones() {
        x6BLE.closeMicrophone(force: true)
        chromecastBLE.closeMicrophone(force: true)
    }

    private func refreshMenuState() {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
        loggingToggleItem?.state = Log.isEnabled ? .on : .off
        refreshSizeLabels()
    }

    private func refreshSizeLabels() {
        logSizeItem?.title = L10n.text("占用", "Size")
            + " · \(AppStorage.formattedSize(Log.byteSize))"
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            headerLabel.title = L10n.text(
                "状态 · 登录启动设置失败",
                "Status · Launch-at-login failed"
            )
        }
        refreshMenuState()
    }

    @objc private func toggleLogging() {
        Log.setEnabled(!Log.isEnabled)
        if Log.isEnabled {
            print("[APP] 日志已由用户开启")
        }
        refreshMenuState()
    }

    @objc private func refreshStorageSizes() {
        refreshSizeLabels()
    }

    @objc private func openLogFolder() {
        AppStorage.ensureDirectory(AppStorage.logsDirectory)
        NSWorkspace.shared.open(AppStorage.logsDirectory)
    }

    @objc private func clearLog() {
        Log.clear()
        refreshSizeLabels()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        x6.stop()
        chromecastHID.stop()
        x6SearchSuppressor.stop()
        x6Session.stop()
        x6BLE.stop()
        chromecastBLE.stop()
        AudioPipe.shared.stop()
    }
}

// MARK: - Entry

#if DEBUG
if CommandLine.arguments.contains("--voice-session-self-test") {
    exit(VoiceSessionSelfTest.run() ? EXIT_SUCCESS : EXIT_FAILURE)
}
if CommandLine.arguments.contains("--mapping-layout-self-test") {
    exit(MappingLayoutSelfTest.run() ? EXIT_SUCCESS : EXIT_FAILURE)
}
if CommandLine.arguments.contains("--mapping-layout-dump") {
    MappingLayoutSelfTest.dump()
    exit(EXIT_SUCCESS)
}
#endif

let app = NSApplication.shared

#if DEBUG
// 界面自查：渲染成 PNG 后直接退出。必须放在 AppController 之前——
// 那之后会起状态栏、BLE、HID，快照不需要这些。
// 顶层代码不是 MainActor，而视图模型是，所以投递到主 actor 上执行。
if UISnapshot.isRequested {
    Task { @MainActor in
        exit(UISnapshot.runIfRequested() ?? EXIT_FAILURE)
    }
    app.run()
}
#endif

let delegate = AppController()
app.delegate = delegate

// Convert SIGTERM (including `kill`/`pkill`) into a normal AppKit
// termination so Option and the CoreAudio IOProc are always released.
signal(SIGTERM, SIG_IGN)
let terminationSignal = DispatchSource.makeSignalSource(
    signal: SIGTERM,
    queue: .main
)
terminationSignal.setEventHandler {
    NSApp.terminate(nil)
}
terminationSignal.resume()

app.run()
