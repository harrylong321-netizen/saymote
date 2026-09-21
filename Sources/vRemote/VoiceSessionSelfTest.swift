#if DEBUG
import CoreAudio
import Foundation

enum VoiceSessionSelfTest {
    private final class FakeDoubaoState: DoubaoAudioStateProviding {
        var onSnapshotChanged: ((DoubaoAudioStateMonitor.Snapshot) -> Void)?
        private(set) var snapshot: DoubaoAudioStateMonitor.Snapshot

        init(state: DoubaoAudioStateMonitor.State = .inactive) {
            snapshot = Self.makeSnapshot(state)
        }

        func start() {}
        func stop() {}

        func snapshotNow() -> DoubaoAudioStateMonitor.Snapshot {
            snapshot
        }

        func emit(_ state: DoubaoAudioStateMonitor.State) {
            snapshot = Self.makeSnapshot(state)
            onSnapshotChanged?(snapshot)
        }

        private static func makeSnapshot(
            _ state: DoubaoAudioStateMonitor.State
        ) -> DoubaoAudioStateMonitor.Snapshot {
            DoubaoAudioStateMonitor.Snapshot(
                state: state,
                pid: 123,
                processObjectID: 456,
                inputDeviceIDs: state == .active ? [789] : [],
                inputDeviceNames: state == .active ? ["vRemoteDr 2ch"] : []
            )
        }
    }

    private final class Harness {
        let doubao: FakeDoubaoState
        let coordinator: X6SessionCoordinator
        var clock = Date(timeIntervalSince1970: 1_000)
        var triggerTapCount = 0
        var routeChanges = [Bool]()
        var openRequests = [(VoiceRemoteID, Bool)]()
        var closeRequestCount = 0
        var openResults = [RemoteMicrophoneOpenResult]()
        var preferredRemote: VoiceRemoteID? = .chromecast

        init(initialState: DoubaoAudioStateMonitor.State = .inactive) {
            doubao = FakeDoubaoState(state: initialState)
            var routeSink: ((Bool) -> Void)?
            var triggerSink: (() -> Void)?
            var nowSink: (() -> Date)?
            coordinator = X6SessionCoordinator(
                doubaoState: doubao,
                setRemoteRouteActive: { routeSink?($0) },
                triggerTap: { triggerSink?() },
                now: { nowSink?() ?? Date(timeIntervalSince1970: 0) }
            )
            routeSink = { [weak self] active in
                self?.routeChanges.append(active)
            }
            triggerSink = { [weak self] in
                self?.triggerTapCount += 1
            }
            nowSink = { [weak self] in
                self?.clock ?? Date(timeIntervalSince1970: 0)
            }
            coordinator.preferredRemoteProvider = { [weak self] in
                self?.preferredRemote
            }
            coordinator.onMicrophoneOpenRequested = {
                [weak self] remote, bypass in
                guard let self else { return .unavailable }
                self.openRequests.append((remote, bypass))
                return self.openResults.isEmpty
                    ? .sent
                    : self.openResults.removeFirst()
            }
            coordinator.onMicrophoneCloseRequested = { [weak self] in
                self?.closeRequestCount += 1
            }
            coordinator.start()
        }

        func advance(_ seconds: TimeInterval) {
            clock = clock.addingTimeInterval(seconds)
        }

        func beginChromecastPress() {
            coordinator.remoteAudioStarted(
                remote: .chromecast,
                reason: 0x03,
                supportsPhysicalHoldGesture: true
            )
        }

        func endChromecastPress() {
            coordinator.remoteAudioStopped(remote: .chromecast, reason: 0x02)
        }
    }

    private final class CheckContext {
        private(set) var failures = 0

        func expect(
            _ condition: @autoclosure () -> Bool,
            _ message: String
        ) {
            if condition() {
                VoiceSessionSelfTest.emit("[SELF-TEST] PASS \(message)")
            } else {
                failures += 1
                VoiceSessionSelfTest.emit("[SELF-TEST] FAIL \(message)")
            }
        }
    }

    private static func emit(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static func run() -> Bool {
        let checks = CheckContext()
        testUnavailableDoubaoClosesSession(checks)
        testUnavailableDoubaoStoppingClosesSession(checks)
        testActiveBeforeRelease(checks)
        testStopBeforeActive(checks)
        testSecondTapCloses(checks)
        testLongPressCloses(checks)
        testKeyboardOpenRemoteClose(checks)
        testRemoteOpenKeyboardClose(checks)
        testX6ReasonZeroOpens(checks)
        testChromecastReasonZeroWhileClosedIsIgnored(checks)
        testIndependentRemoteStops(checks)
        testDebouncedRetry(checks)
        emit("[SELF-TEST] completed failures=\(checks.failures)")
        return checks.failures == 0
    }

    private static func testUnavailableDoubaoClosesSession(_ c: CheckContext) {
        let h = Harness(initialState: .unavailable)
        h.coordinator.triggerDownObserved(isSynthetic: false)
        c.expect(
            h.openRequests.count == 1,
            "unavailable: trigger still requests microphone open"
        )
        // 开麦校验在 +1.0 秒触发；这里留足余量，机器忙的时候也不至于误判。
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        c.expect(
            h.coordinator.debugSnapshot.phase == "open",
            "unavailable: session stays open because state cannot be verified"
        )
    }

    /// 录音中豆包自己收尾（切走窗口 / 输入框消失）时，设备列表会变空。
    /// macOS 12 上这是唯一能用的信号，收到之后必须把遥控器麦克风也关掉，
    /// 不能一直抱着不放。
    private static func testUnavailableDoubaoStoppingClosesSession(
        _ c: CheckContext
    ) {
        let h = Harness(initialState: .unavailable)
        h.coordinator.triggerDownObserved(isSynthetic: false)
        RunLoop.current.run(until: Date().addingTimeInterval(1.6))
        c.expect(
            h.coordinator.debugSnapshot.phase == "open",
            "doubao self-stop: 开麦后先处于已打开"
        )
        // 避开「刚点过触发键」的 1 秒settle窗口，再让设备列表变空。
        h.advance(1.2)
        h.doubao.emit(.unavailable)
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        c.expect(
            h.coordinator.debugSnapshot.phase == "closed",
            "doubao self-stop: 豆包自己停录后会话自动收尾"
        )
        c.expect(
            h.closeRequestCount >= 1,
            "doubao self-stop: 自动收尾要求关闭遥控器麦克风"
        )
        c.expect(
            h.routeChanges.last == false,
            "doubao self-stop: 自动收尾后音频通路已关"
        )
    }

    private static func testActiveBeforeRelease(_ c: CheckContext) {
        let h = Harness()
        h.beginChromecastPress()
        h.doubao.emit(.active)
        c.expect(h.openRequests.isEmpty, "active-before-release waits for physical STOP")
        h.advance(0.18)
        h.endChromecastPress()
        c.expect(h.triggerTapCount == 1, "first short tap sends one trigger")
        c.expect(h.openRequests.count == 1, "physical STOP immediately requests persistent stream")
        c.expect(h.openRequests.first?.0 == .chromecast, "recovery targets Chromecast")
        c.expect(h.openRequests.first?.1 == true, "recovery bypasses transport debounce")
        c.expect(h.coordinator.debugSnapshot.phase == "open", "active-before-release remains open")
    }

    private static func testStopBeforeActive(_ c: CheckContext) {
        let h = Harness()
        h.beginChromecastPress()
        h.advance(0.12)
        h.endChromecastPress()
        c.expect(h.openRequests.count == 1, "stop-before-active also opens without fixed delay")
        h.doubao.emit(.active)
        c.expect(h.openRequests.count == 1, "active confirmation does not duplicate MIC_OPEN")
        c.expect(h.coordinator.debugSnapshot.phase == "open", "late active completes opening")
    }

    private static func testSecondTapCloses(_ c: CheckContext) {
        let h = Harness()
        h.beginChromecastPress()
        h.advance(0.15)
        h.endChromecastPress()
        h.doubao.emit(.active)
        h.coordinator.remoteAudioStarted(remote: .chromecast, reason: 0x00)
        h.beginChromecastPress()
        h.advance(0.16)
        h.endChromecastPress()
        c.expect(h.triggerTapCount == 2, "second short tap sends exactly one close trigger")
        c.expect(h.openRequests.count == 1, "second tap never reopens microphone")
        c.expect(h.coordinator.debugSnapshot.phase == "closing", "second tap enters closing")
    }

    private static func testLongPressCloses(_ c: CheckContext) {
        let h = Harness()
        h.beginChromecastPress()
        h.doubao.emit(.active)
        h.advance(0.70)
        h.endChromecastPress()
        c.expect(h.triggerTapCount == 2, "long release sends one close trigger")
        c.expect(h.openRequests.isEmpty, "long release never requests persistent reopen")
        c.expect(h.coordinator.debugSnapshot.phase == "closing", "long release enters closing")
    }

    private static func testKeyboardOpenRemoteClose(_ c: CheckContext) {
        let h = Harness()
        h.coordinator.triggerDownObserved(isSynthetic: false)
        h.coordinator.triggerUpObserved(isSynthetic: false)
        c.expect(h.triggerTapCount == 0, "physical keyboard open is not replayed")
        c.expect(h.openRequests.first?.0 == .chromecast, "keyboard open selects preferred remote")
        h.doubao.emit(.active)
        h.coordinator.remoteAudioStarted(remote: .chromecast, reason: 0x00)
        h.beginChromecastPress()
        h.advance(0.14)
        h.endChromecastPress()
        c.expect(h.triggerTapCount == 1, "remote can close keyboard-opened session")
        c.expect(h.coordinator.debugSnapshot.phase == "closing", "cross-close enters closing")
    }

    private static func testRemoteOpenKeyboardClose(_ c: CheckContext) {
        let h = Harness()
        h.beginChromecastPress()
        h.advance(0.16)
        h.endChromecastPress()
        h.doubao.emit(.active)
        h.coordinator.remoteAudioStarted(remote: .chromecast, reason: 0x00)
        h.coordinator.triggerDownObserved(isSynthetic: false)
        h.coordinator.triggerUpObserved(isSynthetic: false)
        h.doubao.emit(.active)
        RunLoop.current.run(until: Date().addingTimeInterval(0.22))
        c.expect(h.triggerTapCount == 1, "keyboard close does not synthesize another trigger")
        c.expect(h.openRequests.count == 1, "stale active cannot reopen transport")
        c.expect(h.coordinator.debugSnapshot.phase == "closing", "stale active keeps closing phase")
        h.doubao.emit(.inactive)
        c.expect(h.coordinator.debugSnapshot.phase == "closed", "inactive completes keyboard close")
    }

    private static func testIndependentRemoteStops(_ c: CheckContext) {
        let h = Harness()
        h.coordinator.remoteAudioStarted(remote: .x6, reason: 0x00)
        h.coordinator.remoteAudioStarted(
            remote: .chromecast,
            reason: 0x03,
            supportsPhysicalHoldGesture: true
        )
        c.expect(h.triggerTapCount == 1, "second remote start does not toggle Doubao twice")
        c.expect(
            h.coordinator.debugSnapshot.streamingRemotes == Set([.x6, .chromecast]),
            "both remote transports are tracked independently"
        )
        h.coordinator.remoteAudioStopped(remote: .x6, reason: 0x00)
        c.expect(
            h.coordinator.debugSnapshot.streamingRemotes == Set([.chromecast]),
            "one remote STOP does not erase the other"
        )
    }

    private static func testX6ReasonZeroOpens(_ c: CheckContext) {
        let h = Harness()
        h.coordinator.remoteAudioStarted(remote: .x6, reason: 0x00)
        c.expect(h.triggerTapCount == 1, "X6 physical reason-0 sends one open trigger")
        c.expect(h.coordinator.debugSnapshot.phase == "opening", "X6 reason-0 begins opening")
        c.expect(
            h.coordinator.debugSnapshot.streamingRemotes == Set([.x6]),
            "X6 reason-0 keeps its physical stream"
        )
    }

    private static func testChromecastReasonZeroWhileClosedIsIgnored(
        _ c: CheckContext
    ) {
        let h = Harness()
        h.coordinator.remoteAudioStarted(remote: .chromecast, reason: 0x00)
        c.expect(h.triggerTapCount == 0, "stale Chromecast reason-0 sends no trigger")
        c.expect(h.coordinator.debugSnapshot.phase == "closed", "stale Chromecast reason-0 stays closed")
        c.expect(
            h.coordinator.debugSnapshot.streamingRemotes.isEmpty,
            "stale Chromecast reason-0 is closed locally"
        )
    }

    private static func testDebouncedRetry(_ c: CheckContext) {
        let h = Harness()
        h.openResults = [.retryAfter(0.02), .sent]
        h.beginChromecastPress()
        h.advance(0.13)
        h.endChromecastPress()
        c.expect(h.coordinator.debugSnapshot.openRequestedRemote == nil, "debounced request is not marked sent")
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        c.expect(h.openRequests.count == 2, "debounced open receives a bounded retry")
        c.expect(
            h.coordinator.debugSnapshot.openRequestedRemote == .chromecast,
            "only the sent retry becomes pending"
        )
    }
}

/// 按键映射页的排版自测：连线必须不相交、每栏放得下、两栏不空转。
/// 锚点改动后跑一次（`--mapping-layout-self-test`），别等肉眼发现问题。
enum MappingLayoutSelfTest {
    private static func emit(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private static func aspect(for remote: SupportedRemoteID) -> CGFloat {
        guard let image = RemoteImageAsset.image(for: remote),
              image.size.height > 0
        else { return 0.34 }
        return image.size.width / image.size.height
    }

    /// 把真实排版导出成 JSON，给 `work/make-anchor-preview.py` 画预览图用——
    /// 这样预览和界面是同一次计算，不会各算一套。
    static func dump() {
        for remote in SupportedRemoteID.allCases {
            let layout = RemoteMappingLayout.layout(
                remote: remote,
                width: RemoteMappingLayout.referenceWidth,
                imageAspect: aspect(for: remote),
                isActive: { _ in true }
            )
            func rowsJSON(_ rows: [RemoteMappingLayout.Row]) -> String {
                rows.map { row in
                    let anchor = row.anchor.map {
                        String(format: "{\"x\": %.4f, \"y\": %.4f}", $0.x, $0.y)
                    } ?? "null"
                    return String(
                        format: "{\"id\": \"%@\", \"title\": \"%@\", \"y\": %.1f, \"anchor\": %@}",
                        row.button.id,
                        row.button.title,
                        row.centerY,
                        anchor
                    )
                }.joined(separator: ", ")
            }
            let lines = layout.lines.map { line in
                let points = line.points.map {
                    String(format: "[%.1f, %.1f]", $0.x, $0.y)
                }.joined(separator: ", ")
                return "{\"id\": \"\(line.buttonID)\", \"points\": [\(points)]}"
            }.joined(separator: ", ")
            let json = """
            {"remote": "\(remote.rawValue)", "width": \
            \(RemoteMappingLayout.referenceWidth), \
            "imageOriginX": \(layout.imageOriginX), \
            "imageWidth": \(layout.imageWidth), \
            "imageHeight": \(RemoteMappingLayout.imageHeight), \
            "rowHeight": \(RemoteMappingLayout.rowHeight), \
            "left": [\(rowsJSON(layout.left))], \
            "right": [\(rowsJSON(layout.right))], \
            "lines": [\(lines)]}
            """
            let line = "[MAPPING-LAYOUT] " + json.replacingOccurrences(of: "\n", with: "")
            // 走 FileHandle：`exit()` 不会 flush stdio 缓冲，print 会丢。
            FileHandle.standardOutput.write(Data((line + "\n").utf8))
        }
    }

    static func run() -> Bool {
        var failures = 0
        for remote in SupportedRemoteID.allCases {
            let remoteAspect = aspect(for: remote)
            let layout = RemoteMappingLayout.layout(
                remote: remote,
                width: RemoteMappingLayout.referenceWidth,
                imageAspect: remoteAspect,
                isActive: { _ in true }
            )
            let name = remote.title
            let rows = layout.left.count + layout.right.count
            let maxRows = max(layout.left.count, layout.right.count)
            var crossings = 0
            for i in layout.lines.indices {
                for j in layout.lines.indices where j > i {
                    let a = layout.lines[i]
                    let b = layout.lines[j]
                    func side(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat {
                        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
                    }
                    var crossed = false
                    for ai in 0..<(a.points.count - 1) {
                        for bi in 0..<(b.points.count - 1) {
                            let a1 = a.points[ai]
                            let a2 = a.points[ai + 1]
                            let b1 = b.points[bi]
                            let b2 = b.points[bi + 1]
                            let d1 = side(b1, b2, a1)
                            let d2 = side(b1, b2, a2)
                            let d3 = side(a1, a2, b1)
                            let d4 = side(a1, a2, b2)
                            if ((d1 > 0) != (d2 > 0)), ((d3 > 0) != (d4 > 0)) {
                                crossed = true
                            }
                        }
                    }
                    if crossed {
                        crossings += 1
                        emit("[MAPPING-TEST] ⚠️ \(name) 连线相交：\(a.buttonID) × \(b.buttonID)")
                    }
                }
            }
            // 行和它对应的按键在不在机身同一侧。连线已经不画了，所以这只当参考。
            var strays: [String] = []
            for (side, sideRows) in [("左", layout.left), ("右", layout.right)] {
                for row in sideRows {
                    guard let anchor = row.anchor else { continue }
                    guard abs(anchor.x - 0.5) > RemoteMappingLayout.midlineTolerance
                    else { continue }
                    let belongsLeft = anchor.x < 0.5
                    if belongsLeft != (side == "左") {
                        strays.append("\(row.button.id)@\(side)栏")
                    }
                }
            }
            // 界面上已经不画连线，「相交 / 横穿」看不见了，只当参考信息，
            // 不再作为失败条件（用户指定的分栏本来就不满足这两条）。
            emit(
                "[MAPPING-TEST] \(name) 左栏 \(layout.left.count) 行 / 右栏 "
                    + "\(layout.right.count) 行，共 \(rows) 行；"
                    + "参考：相交 \(crossings) 处、不在同侧 \(strays.count) 处"
            )
            if maxRows > RemoteMappingLayout.maxRowsPerColumn {
                failures += 1
                emit("[MAPPING-TEST] FAIL \(name)：一栏 \(maxRows) 行，超过 \(RemoteMappingLayout.maxRowsPerColumn) 行")
            }
            // 栏内行序必须是锚点 y 升序——分栏表就是按这个规则写的，
            // 顺序一乱，用户指定的那张自上而下的表就对不上了。
            var disorder: [String] = []
            for (side, sideRows) in [("左", layout.left), ("右", layout.right)] {
                let ys = sideRows.compactMap { $0.anchor?.y }
                if ys != ys.sorted() {
                    disorder.append("\(side)栏")
                }
            }
            if disorder.isEmpty {
                emit("[MAPPING-TEST] PASS \(name)：栏内行序按锚点 y 升序")
            } else {
                failures += 1
                emit("[MAPPING-TEST] FAIL \(name)：\(disorder.joined(separator: "、"))行序不是 y 升序")
            }
            if let spec = RemoteMappingLayout.userAssignment[remote] {
                // 用户指定的分栏：断言两栏就是他要的那张表。
                var wrong: [String] = []
                for row in layout.left where spec[row.button.id] != true {
                    wrong.append("\(row.button.id) 该在右栏")
                }
                for row in layout.right where spec[row.button.id] != false {
                    wrong.append("\(row.button.id) 该在左栏")
                }
                if wrong.isEmpty {
                    emit("[MAPPING-TEST] PASS \(name)：分栏与指定的表一致")
                } else {
                    failures += 1
                    emit("[MAPPING-TEST] FAIL \(name)：分栏与指定不一致 —— \(wrong.joined(separator: "、"))")
                }
            } else if crossings > 0 {
                failures += 1
                emit("[MAPPING-TEST] FAIL \(name)：求解器分栏出现 \(crossings) 处相交")
            } else if strays.isEmpty {
                emit("[MAPPING-TEST] PASS \(name)：求解器分栏零相交且不横穿机身")
            } else {
                failures += 1
                emit("[MAPPING-TEST] FAIL \(name)：横穿机身 \(strays.joined(separator: "、"))")
            }
        }
        emit("[MAPPING-TEST] completed failures=\(failures)")
        return failures == 0
    }
}
#endif
