import Foundation

enum VoiceRemoteID: String, CaseIterable {
    case x6
    case chromecast
}

enum RemoteMicrophoneOpenResult: Equatable {
    case sent
    case alreadyStreaming
    case retryAfter(TimeInterval)
    case unavailable
    case failed(String)
}

protocol DoubaoAudioStateProviding: AnyObject {
    var onSnapshotChanged: ((DoubaoAudioStateMonitor.Snapshot) -> Void)? {
        get set
    }

    func start()
    func stop()
    func snapshotNow() -> DoubaoAudioStateMonitor.Snapshot
}

extension DoubaoAudioStateMonitor: DoubaoAudioStateProviding {}

/// Coordinates the input-method toggle, supported remote gestures, and each
/// remote's independent ATVV transport.
///
/// A transport START/STOP is never itself a keyboard toggle. A physical
/// keyboard trigger already reaches Doubao. A remote gesture synthesizes
/// exactly one trigger only when it changes the intended recognition state.
final class X6SessionCoordinator {
    private enum Phase: String {
        case closed
        case opening
        case open
        case closing
    }

    private enum Owner: String {
        case none
        case remote
        case keyboard
    }

    private struct PhysicalVoiceGesture {
        let beganAt: Date
        let recognitionWasOpen: Bool
        /// 豆包在录音、但用的不是我们的虚拟声卡（例如内置麦克风）。
        /// 这种情况下这一按只接管路由、不点豆包——让豆包的「自动检测」
        /// 自己把输入切到遥控器，抬起时也不该补点。
        let switchOnly: Bool
        let generation: UInt64
    }

    struct DebugSnapshot: Equatable {
        let phase: String
        let generation: UInt64
        let sessionRemote: VoiceRemoteID?
        let streamingRemotes: Set<VoiceRemoteID>
        let openRequestedRemote: VoiceRemoteID?
    }

    private static let remoteHoldThreshold: TimeInterval = 0.55
    /// 实测：Chromecast 遥控器的语音键短于约 0.14 秒时，固件不会真正启动
    /// 麦克风（它会确认开麦指令却一个采样都不产生）。低于这个时长就提示用户。
    private static let shortPressThreshold: TimeInterval = 0.15
    /// 开麦后等待音频出现的时长，超过即认为遥控器没有真正开麦。
    private static let audioArrivalTimeout: TimeInterval = 0.5
    /// 短按收尾的等待时长（从开麦检测超时算起）。加上前面的 0.5 秒，
    /// 总时长要超过 tapSettleWindow，读数才可信。
    private static let shortPressRecoveryDelay: TimeInterval = 0.8
    private static let openConfirmationTimeout: TimeInterval = 1.0
    private static let closeVerificationTimeout: TimeInterval = 1.2
    private static let maximumOpenAttempts = 3

    private let doubaoState: any DoubaoAudioStateProviding
    private let setRemoteRouteActive: (Bool) -> Void
    private let triggerTap: () -> Void
    private let now: () -> Date

    private var phase: Phase = .closed
    private var owner: Owner = .none
    private var generation: UInt64 = 0
    private var routeActive = false
    private var sessionRemote: VoiceRemoteID?
    private var streamingRemotes = Set<VoiceRemoteID>()
    private var openRequestedRemote: VoiceRemoteID?
    private var physicalVoiceGestures = [VoiceRemoteID: PhysicalVoiceGesture]()
    /// 本次会话是否已经收到遥控器的音频采样。
    private var audioObservedThisSession = false
    private var audioArrivalCheck: DispatchWorkItem?
    private var shortPressRecoveryWork: DispatchWorkItem?

    /// 遥控器没有真正开麦时置位，供菜单栏显示明确提示。
    private(set) var audioWarningText: String?
    /// 菜单栏图标旁边显示的短提示（菜单栏空间有限）。
    private(set) var audioWarningShortText: String?
    /// 每次出现新的告警就 +1，供外部判断「这是不是一条新提示」。
    private(set) var audioWarningSerial = 0
    /// App 最近一次发出触发键点击的时间。豆包启动/停止需要时间（实测约
    /// 0.8 秒），刚点完就重新读数会拿到过期值，所以要避开这个窗口。
    private var lastTriggerTapAt: Date?
    private static let tapSettleWindow: TimeInterval = 1.0

    private var routeCloseWorkItem: DispatchWorkItem?
    private var startVerificationWorkItem: DispatchWorkItem?
    private var closeVerificationWorkItem: DispatchWorkItem?
    private var openRetryWorkItem: DispatchWorkItem?
    private var openConfirmationWorkItem: DispatchWorkItem?

    var preferredRemoteProvider: (() -> VoiceRemoteID?)?
    var onMicrophoneOpenRequested:
        ((VoiceRemoteID, Bool) -> RemoteMicrophoneOpenResult)?
    var onMicrophoneCloseRequested: (() -> Void)?
    var onStateChanged: ((String) -> Void)?

    init(
        doubaoState: any DoubaoAudioStateProviding,
        setRemoteRouteActive: @escaping (Bool) -> Void = {
            AudioPipe.shared.setRemoteActive($0)
        },
        triggerTap: @escaping () -> Void = { Key.triggerTap() },
        now: @escaping () -> Date = Date.init
    ) {
        self.doubaoState = doubaoState
        self.setRemoteRouteActive = setRemoteRouteActive
        self.triggerTap = triggerTap
        self.now = now
    }

    var debugSnapshot: DebugSnapshot {
        DebugSnapshot(
            phase: phase.rawValue,
            generation: generation,
            sessionRemote: sessionRemote,
            streamingRemotes: streamingRemotes,
            openRequestedRemote: openRequestedRemote
        )
    }

    func start() {
        doubaoState.onSnapshotChanged = { [weak self] snapshot in
            self?.handleDoubaoSnapshot(snapshot)
        }
        doubaoState.start()
    }

    // MARK: - ATVV transport

    func remoteAudioStarted(
        remote: VoiceRemoteID,
        reason: UInt8,
        supportsPhysicalHoldGesture: Bool = false
    ) {
        let snapshot = doubaoState.snapshotNow()
        let inserted = streamingRemotes.insert(remote).inserted
        if openRequestedRemote == remote {
            openRequestedRemote = nil
            openConfirmationWorkItem?.cancel()
            openConfirmationWorkItem = nil
        }

        if phase == .closing {
            print(
                "[VOICE-SESSION] late AUDIO_START while closing " +
                "remote=\(remote.rawValue) reason=" +
                String(format: "0x%02x", reason)
            )
            closeAllRemoteTransports()
            return
        }

        if supportsPhysicalHoldGesture, reason == 0x03 {
            let recording = trustedDoubaoRecording()

            // 情况三：豆包正在录音，但用的不是我们的虚拟声卡（例如内置麦克风）。
            // 这一下不该点豆包（那会把它关掉），只把我们的路由打开，
            // 让豆包的「自动检测」按“哪个设备在用”自己切到遥控器。
            if recording == true, trustedDoubaoUsesVRemote() == false {
                generation &+= 1
                cancelScheduledWork()
                phase = .open
                owner = .remote
                sessionRemote = remote
                activateRemoteRoute()
                if physicalVoiceGestures[remote] == nil {
                    physicalVoiceGestures[remote] = PhysicalVoiceGesture(
                        beganAt: now(),
                        recognitionWasOpen: true,
                        switchOnly: true,
                        generation: generation
                    )
                }
                requestRemoteTransportOpen(
                    remote,
                    bypassDebounce: false,
                    attempt: 1
                )
                print(
                    "[VOICE-SESSION] 豆包在录音但用的不是遥控器麦克风：" +
                    "只切路由、不点它，等自动检测切过来"
                )
                publish("已切到遥控器麦克风")
                return
            }

            // 「这一下该开还是该关」同样以豆包的真实状态为准；读数不可采信时
            // 才退回 App 自己的阶段记录。
            let recognitionWasOpen = recording ?? (phase == .open)
            if physicalVoiceGestures[remote] == nil {
                physicalVoiceGestures[remote] = PhysicalVoiceGesture(
                    beganAt: now(),
                    recognitionWasOpen: recognitionWasOpen,
                    switchOnly: false,
                    generation: generation
                )
            }
            print(
                "[VOICE-SESSION] physical ATVV DOWN " +
                "remote=\(remote.rawValue) " +
                "recognitionWasOpen=\(recognitionWasOpen)"
            )

            if recognitionWasOpen {
                sessionRemote = remote
                activateRemoteRoute()
                publish("遥控器按住录音中")
                return
            }
        }

        if !inserted {
            print(
                "[VOICE-SESSION] duplicate AUDIO_START ignored " +
                "remote=\(remote.rawValue) reason=" +
                String(format: "0x%02x", reason)
            )
            return
        }

        activateRemoteRoute()
        print(
            "[VOICE-SESSION] AUDIO_START remote=\(remote.rawValue) reason=" +
            String(format: "0x%02x", reason) +
            " phase=\(phase.rawValue) owner=\(owner.rawValue) " +
            "doubaoBefore=\(snapshot.state.rawValue) " +
            "device=\(snapshot.deviceSummary)"
        )

        switch phase {
        case .opening, .open:
            publish("豆包录音中 · 遥控器已接入")

        case .closed:
            // Chromecast reserves reason 0x03 for a physical voice press, so
            // a reason-0 stream while closed can only be a stale response to
            // an earlier host request. X6 is different: its verified physical
            // first press itself arrives as reason 0x00 and must remain a
            // valid open gesture.
            guard remote != .chromecast || reason != 0x00 else {
                print(
                    "[VOICE-SESSION] stale host AUDIO_START ignored " +
                    "remote=\(remote.rawValue)"
                )
                closeAllRemoteTransports()
                return
            }
            beginOpening(
                owner: .remote,
                remote: remote,
                sendTrigger: true,
                requestTransportImmediately: false
            )
            // beginOpening advances the session generation. Keep the
            // in-flight physical gesture attached to that new session so its
            // matching AUDIO_STOP can complete the tap/hold decision.
            if supportsPhysicalHoldGesture,
               reason == 0x03,
               let gesture = physicalVoiceGestures[remote]
            {
                physicalVoiceGestures[remote] = PhysicalVoiceGesture(
                    beganAt: gesture.beganAt,
                    recognitionWasOpen: gesture.recognitionWasOpen,
                    switchOnly: gesture.switchOnly,
                    generation: generation
                )
            }

        case .closing:
            break
        }
    }

    func remoteAudioStopped(remote: VoiceRemoteID, reason: UInt8) {
        streamingRemotes.remove(remote)
        if openRequestedRemote == remote {
            openRequestedRemote = nil
            openConfirmationWorkItem?.cancel()
            openConfirmationWorkItem = nil
        }

        if reason == 0x02,
           let gesture = physicalVoiceGestures.removeValue(forKey: remote)
        {
            let duration = now().timeIntervalSince(gesture.beganAt)
            let wasHold = duration >= Self.remoteHoldThreshold
            print(
                String(
                    format:
                        "[VOICE-SESSION] physical ATVV UP remote=%@ " +
                        "duration=%.3fs kind=%@ recognitionWasOpen=%@",
                    remote.rawValue,
                    duration,
                    wasHold ? "HOLD" : "TAP",
                    gesture.recognitionWasOpen ? "true" : "false"
                )
            )

            guard gesture.generation == generation else {
                print(
                    "[VOICE-SESSION] stale physical release ignored " +
                    "remote=\(remote.rawValue)"
                )
                return
            }

            // 「只切路由」那一按本来就没点豆包，抬起时也不要补点：
            // 豆包应该继续录着，只是把输入源换成了遥控器。
            if gesture.switchOnly {
                print(
                    "[VOICE-SESSION] switch-only 手势结束，不点豆包"
                )
                return
            }

            if wasHold || gesture.recognitionWasOpen {
                closeRecognitionFromRemote(
                    reason: wasHold
                        ? "ATVV HOLD release"
                        : "ATVV TAP toggle"
                )
                return
            }

            // First Chromecast short tap: the physical stream ends at button
            // release. Immediately request a persistent stream from that same
            // remote. BLEBridge has already marked its local stream idle
            // before invoking this callback, so no fixed delay is necessary.
            guard phase == .opening || phase == .open else { return }
            sessionRemote = remote
            requestRemoteTransportOpen(
                remote,
                bypassDebounce: true,
                attempt: 1
            )
            scheduleAudioArrivalCheck(pressDuration: duration)
            publish("豆包录音中 · 遥控器持续收音")
            return
        }

        print(
            "[VOICE-SESSION] AUDIO_STOP remote=\(remote.rawValue) reason=" +
            String(format: "0x%02x", reason) +
            " phase=\(phase.rawValue)"
        )

        // Do not automatically reopen a generic transport STOP. X6 may emit
        // it immediately before its HID toggle-off edge. Only the proven
        // Chromecast physical-tap path above performs an immediate recovery.
        if phase == .open || phase == .opening {
            publish("豆包仍开启 · 遥控器音频已停止")
        } else if streamingRemotes.isEmpty {
            scheduleRouteClose(after: 0.08)
        }
    }

    func remoteDisconnected(_ remote: VoiceRemoteID) {
        streamingRemotes.remove(remote)
        physicalVoiceGestures.removeValue(forKey: remote)
        if openRequestedRemote == remote {
            openRequestedRemote = nil
            openRetryWorkItem?.cancel()
            openRetryWorkItem = nil
            openConfirmationWorkItem?.cancel()
            openConfirmationWorkItem = nil
        }

        guard sessionRemote == remote else { return }
        sessionRemote = preferredRemoteProvider?()
        guard phase == .opening || phase == .open,
              let replacement = sessionRemote
        else { return }
        requestRemoteTransportOpen(
            replacement,
            bypassDebounce: false,
            attempt: 1
        )
    }

    func remoteMicrophoneOpenFailed(remote: VoiceRemoteID, code: UInt16) {
        guard openRequestedRemote == remote,
              phase == .opening || phase == .open
        else { return }
        openRequestedRemote = nil
        openConfirmationWorkItem?.cancel()
        openConfirmationWorkItem = nil
        print(
            "[VOICE-SESSION] MIC_OPEN failed remote=\(remote.rawValue) " +
            String(format: "code=0x%04x", code)
        )
        scheduleOpenRetry(remote: remote, after: 0.20, attempt: 2)
    }

    // MARK: - X6 HID completion

    func remoteHIDShortPress() {
        closeRecognitionFromRemote(reason: "HID SHORT")
    }

    func remoteHIDLongPressEnded() {
        closeRecognitionFromRemote(reason: "HID LONG release")
    }

    // MARK: - Physical keyboard trigger

    /// Called before the real physical trigger reaches Doubao. It updates the
    /// remote transport only; it never synthesizes a second keyboard event.
    func triggerDownObserved(isSynthetic: Bool) {
        guard !isSynthetic else { return }
        let snapshot = doubaoState.snapshotNow()
        let trustedRecording = trustedDoubaoRecording()
        let shouldOpen: Bool
        if phase == .closing {
            // A second deliberate physical trigger reverses the user's last
            // intent even if CoreAudio has not published inactive yet.
            shouldOpen = true
        } else if let recording = trustedRecording {
            // 以豆包的真实状态为准：它在录，这一下就该关；它没在录，就该开。
            // 这样即使 App 的阶段与豆包错位（例如豆包在 App 之外被开关过，
            // 或短按失败后留下假状态），按键方向依然是对的。
            shouldOpen = !recording
        } else {
            shouldOpen = !(phase == .open || phase == .opening)
        }

        print(
            "[TRIGGER] DOWN source=keyboard action=" +
            (shouldOpen ? "open" : "close") +
            " phase=\(phase.rawValue) " +
            "doubaoBefore=\(snapshot.state.rawValue) " +
            "device=\(snapshot.deviceSummary) " +
            "doubaoRecording=\(trustedRecording.map { $0 ? "yes" : "no" } ?? "unknown")"
        )

        if shouldOpen {
            guard let remote = preferredRemoteProvider?() else {
                beginOpeningWithoutRemote()
                return
            }
            beginOpening(
                owner: .keyboard,
                remote: remote,
                sendTrigger: false,
                requestTransportImmediately: true
            )
        } else {
            beginClosing(sendTrigger: false, reason: "keyboard trigger")
        }
    }

    func triggerUpObserved(isSynthetic: Bool) {
        guard !isSynthetic else { return }
        print(
            "[TRIGGER] UP source=keyboard phase=\(phase.rawValue) " +
            "owner=\(owner.rawValue)"
        )
        reconcileSoon(after: 0.03)
        reconcileSoon(after: 0.15)
    }

    // MARK: - Lifecycle / manual control

    func forceClose() {
        generation &+= 1
        cancelScheduledWork()
        phase = .closed
        owner = .none
        sessionRemote = nil
        physicalVoiceGestures.removeAll()
        closeRouteAndTransports()
        publish("已手动关闭")
    }

    func stop() {
        forceClose()
        doubaoState.stop()
    }

    // MARK: - Doubao observation

    private func handleDoubaoSnapshot(
        _ snapshot: DoubaoAudioStateMonitor.Snapshot
    ) {
        switch snapshot.state {
        case .active:
            switch phase {
            case .opening:
                startVerificationWorkItem?.cancel()
                startVerificationWorkItem = nil
                phase = .open
                activateRemoteRoute()
                if let remote = sessionRemote,
                   !streamingRemotes.contains(remote),
                   openRequestedRemote != remote
                {
                    requestRemoteTransportOpen(
                        remote,
                        bypassDebounce: false,
                        attempt: 1
                    )
                }
                publish("豆包录音中 · \(snapshot.deviceSummary)")

            case .open:
                activateRemoteRoute()
                publish("豆包录音中 · \(snapshot.deviceSummary)")

            case .closing:
                // CoreAudio can remain active briefly after the trigger has
                // toggled Doubao off. Never reinterpret this stale edge as a
                // fresh external opening.
                print(
                    "[VOICE-SESSION] active snapshot ignored while closing"
                )

            case .closed:
                adoptExternalActivation(snapshot)
            }

        case .inactive:
            switch phase {
            case .opening:
                // The opening verification owns this transient idle window.
                break
            case .open, .closing:
                finalizeClosed(reason: "Doubao inactive")
            case .closed:
                if routeActive || !streamingRemotes.isEmpty {
                    closeRouteAndTransports()
                }
            }
            publish("豆包已就绪")

        case .unavailable:
            // 该状态表示“观测不到豆包的录音状态”，而不是“豆包没有在录音”。
            // 在 macOS 14.2 之前，CoreAudio 不提供
            // kAudioProcessPropertyIsRunningInput，因此这里会长期为
            // unavailable。此时若按“未录音”处理，会在用户刚开始说话时
            // 就把会话关掉，故保持已打开的会话，交给用户手势关闭。
            //
            // 反过来，如果设备列表显示豆包确实在录音、而 App 还停在“已关闭”，
            // 说明豆包在 App 之外被打开了（或者上次的关闭点击没生效）。
            // 这时要跟上去，否则 App 会一直是关闭状态，按键看起来没反应。
            // 只在豆包用的就是我们的虚拟声卡时才接管：如果它用的是内置麦克风，
            // 说明用户正在电脑边用电脑麦克风，App 不该抢过来（否则会形成
            // “豆包一直录、App 一直开路由”的循环）。
            if snapshot.hasInputDevice,
               snapshot.inputDeviceNames.contains(Self.vRemoteDeviceName),
               phase == .closed {
                adoptExternalActivation(snapshot)
                return
            }
            if phase == .open {
                publish("豆包录音中 · 无法校验")
                break
            }
            if phase != .opening {
                finalizeClosed(reason: "Doubao unavailable")
            }
            publish("等待豆包输入法")
        }
    }

    private func adoptExternalActivation(
        _ snapshot: DoubaoAudioStateMonitor.Snapshot
    ) {
        generation &+= 1
        cancelScheduledWork()
        phase = .open
        owner = .keyboard
        sessionRemote = preferredRemoteProvider?()
        activateRemoteRoute()
        print(
            "[VOICE-SESSION] Doubao external activation adopted " +
            "device=\(snapshot.deviceSummary)"
        )
        if let remote = sessionRemote {
            requestRemoteTransportOpen(
                remote,
                bypassDebounce: false,
                attempt: 1
            )
        }
        publish("豆包录音中 · \(snapshot.deviceSummary)")
    }

    // MARK: - State transitions

    private func beginOpeningWithoutRemote() {
        generation &+= 1
        cancelScheduledWork()
        audioObservedThisSession = false
        clearAudioWarning()
        phase = .opening
        owner = .keyboard
        sessionRemote = nil
        activateRemoteRoute()
        scheduleStartVerification(for: generation)
        publish("豆包正在启动 · 等待遥控器")
    }

    private func beginOpening(
        owner: Owner,
        remote: VoiceRemoteID,
        sendTrigger: Bool,
        requestTransportImmediately: Bool
    ) {
        generation &+= 1
        cancelScheduledWork()
        phase = .opening
        self.owner = owner
        sessionRemote = remote
        activateRemoteRoute()
        logDoubaoInputDevice("tap-open-before")
        if sendTrigger {
            tapTrigger()
        }
        scheduleDoubaoProbe("tap-open-after-0.8s", after: 0.8)
        if requestTransportImmediately {
            requestRemoteTransportOpen(
                remote,
                bypassDebounce: false,
                attempt: 1
            )
        }
        scheduleStartVerification(for: generation)
        publish(
            owner == .keyboard
                ? "豆包正在启动 · 遥控器已预热"
                : "遥控器已启动 · 正在打开豆包"
        )
    }

    private func closeRecognitionFromRemote(reason: String) {
        guard phase == .opening || phase == .open else {
            // App 自己的阶段是「已关闭」，但豆包可能仍在录音——例如上一次
            // 关闭点击没被豆包接收，或者豆包在 App 之外被打开了。这时用户按
            // 这一下就是想停止录音，不能直接忽略（忽略会让按键看起来完全没反应，
            // 而且用户再也停不下来）。以豆包的真实状态为准：确实在录就补一次点击。
            if trustedDoubaoRecording() == true {
                print(
                    "[VOICE-SESSION] \(reason)：App 处于已关闭但豆包仍在录音，" +
                    "补一次点击停止它"
                )
                tapTrigger()
                finalizeClosed(reason: "\(reason) recovered while closed")
                return
            }
            print(
                "[VOICE-SESSION] \(reason) ignored phase=\(phase.rawValue)"
            )
            return
        }
        beginClosing(sendTrigger: true, reason: reason)
    }

    private func beginClosing(sendTrigger: Bool, reason: String) {
        guard phase != .closed, phase != .closing else {
            print(
                "[VOICE-SESSION] close ignored phase=\(phase.rawValue) " +
                "reason=\(reason)"
            )
            return
        }

        generation &+= 1
        cancelScheduledWork()
        phase = .closing
        owner = .none
        openRequestedRemote = nil
        // 触发键只在「豆包确实在录音」时才需要点。豆包本来就没在录时再点一下，
        // 反而会把它打开、制造状态错位（实测抓到过一次）。读数不可采信时保持
        // 原有行为。
        let trustedRecording = trustedDoubaoRecording()
        logDoubaoInputDevice("tap-close-before")
        let shouldTapTrigger = sendTrigger && (trustedRecording ?? true)
        if shouldTapTrigger {
            tapTrigger()
        } else if sendTrigger, trustedRecording == false {
            print("[VOICE-SESSION] 豆包并未在录音，跳过这次的触发键点击")
        }
        scheduleDoubaoProbe("tap-close-after-0.8s", after: 0.8)
        scheduleRouteClose(after: 0.10)
        scheduleCloseVerification(for: generation)
        publish("遥控器已结束 · 正在关闭豆包")
        print(
            "[VOICE-SESSION] begin closing reason=\(reason) " +
            "trigger=\(sendTrigger ? "synthetic" : "physical")"
        )
    }

    private func finalizeClosed(reason: String) {
        generation &+= 1
        cancelScheduledWork()
        audioObservedThisSession = false
        clearAudioWarning()
        phase = .closed
        owner = .none
        sessionRemote = nil
        physicalVoiceGestures.removeAll()
        closeRouteAndTransports()
        print("[VOICE-SESSION] closed reason=\(reason)")
    }

    // MARK: - Remote transport requests

    private func requestRemoteTransportOpen(
        _ remote: VoiceRemoteID,
        bypassDebounce: Bool,
        attempt: Int
    ) {
        guard phase == .opening || phase == .open,
              !streamingRemotes.contains(remote),
              openRequestedRemote != remote
        else { return }

        guard let request = onMicrophoneOpenRequested else {
            print(
                "[VOICE-SESSION] MIC_OPEN unavailable " +
                "remote=\(remote.rawValue)"
            )
            return
        }

        let result = request(remote, bypassDebounce)
        switch result {
        case .sent:
            openRequestedRemote = remote
            scheduleOpenConfirmation(
                remote: remote,
                attempt: attempt,
                generation: generation
            )
            print(
                "[VOICE-SESSION] MIC_OPEN sent remote=\(remote.rawValue) " +
                "attempt=\(attempt)"
            )

        case .alreadyStreaming:
            streamingRemotes.insert(remote)
            openRequestedRemote = nil
            print(
                "[VOICE-SESSION] MIC_OPEN already streaming " +
                "remote=\(remote.rawValue)"
            )

        case .retryAfter(let delay):
            scheduleOpenRetry(
                remote: remote,
                after: delay,
                attempt: attempt + 1
            )

        case .unavailable:
            print(
                "[VOICE-SESSION] MIC_OPEN target unavailable " +
                "remote=\(remote.rawValue)"
            )

        case .failed(let message):
            print(
                "[VOICE-SESSION] MIC_OPEN failed remote=\(remote.rawValue) " +
                "message=\(message)"
            )
            scheduleOpenRetry(
                remote: remote,
                after: 0.20,
                attempt: attempt + 1
            )
        }
    }

    private func scheduleOpenRetry(
        remote: VoiceRemoteID,
        after delay: TimeInterval,
        attempt: Int
    ) {
        guard attempt <= Self.maximumOpenAttempts else {
            print(
                "[VOICE-SESSION] MIC_OPEN retries exhausted " +
                "remote=\(remote.rawValue)"
            )
            return
        }
        openRetryWorkItem?.cancel()
        let expectedGeneration = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.phase == .opening || self.phase == .open
            else { return }
            self.openRetryWorkItem = nil
            self.requestRemoteTransportOpen(
                remote,
                bypassDebounce: true,
                attempt: attempt
            )
        }
        openRetryWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0.01, delay),
            execute: work
        )
    }

    private func scheduleOpenConfirmation(
        remote: VoiceRemoteID,
        attempt: Int,
        generation expectedGeneration: UInt64
    ) {
        openConfirmationWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.openRequestedRemote == remote,
                  !self.streamingRemotes.contains(remote),
                  self.phase == .opening || self.phase == .open
            else { return }
            self.openRequestedRemote = nil
            self.openConfirmationWorkItem = nil
            print(
                "[VOICE-SESSION] MIC_OPEN confirmation timeout " +
                "remote=\(remote.rawValue) attempt=\(attempt)"
            )
            self.scheduleOpenRetry(
                remote: remote,
                after: 0.05,
                attempt: attempt + 1
            )
        }
        openConfirmationWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.openConfirmationTimeout,
            execute: work
        )
    }

    // MARK: - Verification and route lifecycle

    private func scheduleStartVerification(for expectedGeneration: UInt64) {
        startVerificationWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.phase == .opening
            else { return }
            self.startVerificationWorkItem = nil
            let snapshot = self.doubaoState.snapshotNow()
            if snapshot.isRecording {
                self.handleDoubaoSnapshot(snapshot)
                return
            }
            // 同上：状态不可观测时不能判定为“豆包未启动”，否则遥控器
            // 会在 1 秒后被自动关闭。
            if snapshot.state == .unavailable {
                self.phase = .open
                self.publish("豆包录音中 · 无法校验")
                print(
                    "[VOICE-SESSION] start verification skipped: " +
                    "Doubao state unavailable"
                )
                return
            }
            self.finalizeClosed(reason: "opening timeout")
            self.publish("豆包未启动 · 遥控器自动关闭")
        }
        startVerificationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func scheduleCloseVerification(for expectedGeneration: UInt64) {
        closeVerificationWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.phase == .closing
            else { return }
            self.closeVerificationWorkItem = nil
            let snapshot = self.doubaoState.snapshotNow()
            if snapshot.isRecording {
                // The requested close did not become observable. Follow the
                // real CoreAudio state without synthesizing another trigger.
                self.phase = .open
                self.owner = .keyboard
                self.sessionRemote = self.preferredRemoteProvider?()
                self.activateRemoteRoute()
                if let remote = self.sessionRemote {
                    self.requestRemoteTransportOpen(
                        remote,
                        bypassDebounce: false,
                        attempt: 1
                    )
                }
                self.publish("豆包仍在录音 · 请再次关闭")
                print(
                    "[VOICE-SESSION] close not observed; restored open state"
                )
            } else {
                self.finalizeClosed(reason: "close verification")
                self.publish("豆包已就绪")
            }
        }
        closeVerificationWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.closeVerificationTimeout,
            execute: work
        )
    }

    private func reconcileSoon(after delay: TimeInterval) {
        let expectedGeneration = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == expectedGeneration else { return }
            self.handleDoubaoSnapshot(self.doubaoState.snapshotNow())
        }
    }

    private func activateRemoteRoute() {
        routeCloseWorkItem?.cancel()
        routeCloseWorkItem = nil
        guard !routeActive else { return }
        routeActive = true
        setRemoteRouteActive(true)
        print(
            "[VOICE-SESSION] audio route ON phase=\(phase.rawValue) " +
            "owner=\(owner.rawValue)"
        )
    }

    private func scheduleRouteClose(after delay: TimeInterval) {
        routeCloseWorkItem?.cancel()
        let expectedGeneration = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == expectedGeneration else { return }
            self.routeCloseWorkItem = nil
            self.closeRouteAndTransports()
        }
        routeCloseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func closeAllRemoteTransports() {
        onMicrophoneCloseRequested?()
        streamingRemotes.removeAll()
        openRequestedRemote = nil
        openRetryWorkItem?.cancel()
        openRetryWorkItem = nil
        openConfirmationWorkItem?.cancel()
        openConfirmationWorkItem = nil
    }

    private func closeRouteAndTransports() {
        let hadTransport =
            !streamingRemotes.isEmpty || openRequestedRemote != nil
        routeActive = false
        setRemoteRouteActive(false)
        if hadTransport {
            closeAllRemoteTransports()
        }
        print("[VOICE-SESSION] audio route OFF")
    }

    private func cancelScheduledWork() {
        routeCloseWorkItem?.cancel()
        routeCloseWorkItem = nil
        startVerificationWorkItem?.cancel()
        startVerificationWorkItem = nil
        closeVerificationWorkItem?.cancel()
        closeVerificationWorkItem = nil
        openRetryWorkItem?.cancel()
        openRetryWorkItem = nil
        openConfirmationWorkItem?.cancel()
        openConfirmationWorkItem = nil
        audioArrivalCheck?.cancel()
        audioArrivalCheck = nil
        shortPressRecoveryWork?.cancel()
        shortPressRecoveryWork = nil
    }

    private func publish(_ status: String) {
        onStateChanged?(status)
    }

    // MARK: - Remote microphone health

    /// 触发键点击的唯一出口：记录时间，供 `trustedDoubaoRecording()` 判断
    /// 读数是否已经稳定。
    private func tapTrigger() {
        lastTriggerTapAt = now()
        triggerTap()
    }

    /// 豆包是否正在录音。返回 nil 表示读数不可采信（绑定不到豆包进程，
    /// 或者刚发过触发键、状态还没稳定）。
    ///
    /// macOS 14.2+ 用系统的 `isRunningInput`；这台 macOS 12 上没有该属性，
    /// 改用「豆包进程正占着某个输入设备」来判断——本机实测：两次完整开关
    /// 循环里，设备列表非空 ⟺ 豆包正在录音，读数零抖动。
    private static let vRemoteDeviceName = "vRemoteDr 2ch"

    /// 可信的豆包状态读数。nil 表示不可采信（绑定不到豆包进程，
    /// 或者刚发过触发键、状态还没稳定下来）。
    private func trustedDoubaoSnapshot() -> DoubaoAudioStateMonitor.Snapshot? {
        if let last = lastTriggerTapAt,
           now().timeIntervalSince(last) < Self.tapSettleWindow {
            return nil
        }
        let snapshot = doubaoState.snapshotNow()
        guard snapshot.processObjectID != nil else { return nil }
        return snapshot
    }

    private func trustedDoubaoRecording() -> Bool? {
        guard let snapshot = trustedDoubaoSnapshot() else { return nil }
        return snapshot.isRecording || snapshot.hasInputDevice
    }

    /// 豆包正在录音，而且用的就是我们的虚拟声卡。返回 false 表示它虽然
    /// 在录音，但走的是别的麦克风（例如内置麦克风）。
    private func trustedDoubaoUsesVRemote() -> Bool? {
        guard let snapshot = trustedDoubaoSnapshot() else { return nil }
        guard snapshot.isRecording || snapshot.hasInputDevice else { return false }
        return snapshot.inputDeviceNames.contains(Self.vRemoteDeviceName)
    }

    /// 诊断（第一步，只读不写）：记录豆包当前占用的输入设备，用来验证
    /// 「设备列表非空 = 豆包正在录音」「列表内容 = 豆包用的是哪个麦克风」
    /// 这两条推断在你这台机器上是否稳定。不参与任何决策。
    func logDoubaoInputDevice(_ stage: String) {
        let snapshot = doubaoState.snapshotNow()
        let devices = snapshot.inputDeviceNames.isEmpty
            ? "（无）"
            : snapshot.inputDeviceNames.joined(separator: "、")
        print(
            "[DOUBAO-PROBE] \(stage) recording=\(snapshot.hasInputDevice ? "yes" : "no") " +
            "devices=\(devices) vRemote=\(snapshot.inputDeviceNames.contains("vRemoteDr 2ch") ? "yes" : "no")"
        )
    }

    private func scheduleDoubaoProbe(_ stage: String, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.logDoubaoInputDevice(stage)
        }
    }

    /// 短按没有真正开麦之后的收尾。
    ///
    /// 遥控器固件不会为过短的按键启动麦克风，但 App 那一下触发键点击是发出去了的
    /// ——豆包很可能已经打开、正在录静音。如果不处理，App 就会一直停在「麦克风
    /// 已打开」的假状态，下一次按键会被当成关闭。
    ///
    /// 但**不能盲目再点一次**（0.5 秒内连点两次会被豆包忽略，反而制造错位，
    /// 这是之前踩过的坑）：这里等读数稳定后再确认——只有确认豆包确实在录音，
    /// 才补一次点击把它关掉；确认没在录就不点。之后把会话回到「已关闭」，
    /// 让下一次按键重新回到「第一下 = 开始」。
    private func scheduleShortPressRecovery(
        expectedGeneration: UInt64,
        text: String,
        shortText: String
    ) {
        shortPressRecoveryWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.phase == .open || self.phase == .opening
            else { return }
            guard let recording = self.trustedDoubaoRecording() else {
                print("[VOICE-SESSION] 短按收尾：豆包状态仍不可采信，本次不处理")
                return
            }
            if recording {
                print("[VOICE-SESSION] 短按收尾：确认豆包在录音，补一次点击关闭它")
                self.tapTrigger()
            } else {
                print("[VOICE-SESSION] 短按收尾：豆包并未在录音，无需点击")
            }
            self.finalizeClosed(reason: "short press recovery")
            // finalizeClosed 会清掉提示，这里恢复，让用户仍能看到失败原因。
            self.audioWarningText = text
            self.audioWarningShortText = shortText
            self.publish(text)
        }
        shortPressRecoveryWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.shortPressRecoveryDelay,
            execute: work
        )
    }

    /// 遥控器音频已经到达：清掉「没有开麦」的提示。
    func remoteAudioObserved() {
        audioObservedThisSession = true
        guard audioWarningText != nil else { return }
        clearAudioWarning()
        publish("豆包录音中 · 遥控器持续收音")
    }

    private func clearAudioWarning() {
        audioWarningText = nil
        audioWarningShortText = nil
    }

    /// 开麦指令发出后等待音频。超时未收到音频时给出明确提示并在日志里
    /// 记录原因——短按（< 0.15s）是已知的硬件限制：遥控器固件会确认指令
    /// 但一个采样都不产生。
    ///
    /// 注意：这里**不再**补发触发键去「撤销」。曾经这么做过，结果是 0.5 秒内
    /// 连点两次触发键，豆包在启动过程中会忽略第二次，于是豆包停在「开」而
    /// App 以为「关」，用户再按一次反而把豆包关掉——语音彻底录不进去。
    /// 在拿不到豆包真实状态之前，不做这种盲目的二次点击。
    private func scheduleAudioArrivalCheck(pressDuration: TimeInterval) {
        audioArrivalCheck?.cancel()
        let expectedGeneration = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  !self.audioObservedThisSession
            else { return }
            let tooShort = pressDuration < Self.shortPressThreshold
            let text = tooShort
                ? L10n.text("按键太短 · 遥控器未开麦（请按住 0.2 秒）",
                            "Press too short · Remote mic stayed off (hold 0.2s)")
                : L10n.text("遥控器未送出音频",
                            "Remote sent no audio")
            let shortText = tooShort
                ? L10n.text("按键太短 · 按住 0.2 秒", "Too short · hold 0.2s")
                : L10n.text("遥控器无音频", "No remote audio")
            self.audioWarningText = text
            self.audioWarningShortText = shortText
            self.audioWarningSerial += 1
            print(
                String(
                    format:
                        "[VOICE-SESSION] ⚠️ 遥控器没有开麦 " +
                        "press=%.3fs short=%@",
                    pressDuration,
                    tooShort ? "true" : "false"
                )
            )
            print("[VOICE-SESSION] ⚠️ \(text)")
            self.publish(text)
            if tooShort {
                self.scheduleShortPressRecovery(
                    expectedGeneration: expectedGeneration,
                    text: text,
                    shortText: shortText
                )
            }
        }
        audioArrivalCheck = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.audioArrivalTimeout,
            execute: work
        )
    }
}
