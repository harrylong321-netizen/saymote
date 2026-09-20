// vRemote audio pipe.
//
// X6 / Chromecast ATVV ADPCM -> decoded Int16 PCM -> vRemoteDr 2ch
// （设备在系统里的名字是 vRemoteDr 2ch，vRemoter 界面里显示为「遥控器麦克风」）
//
// 本版本只保留遥控器麦克风通路：MacBook 内置麦克风已移除，
// 因此不再有采集会话、双麦混音与延迟对齐。

import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

final class AudioPipe: NSObject {
    static let shared = AudioPipe()

    private static let targetDeviceName = "vRemoteDr 2ch"
    private static let outputSampleRate: Double = 48_000
    private static let outputChannels: AVAudioChannelCount = 2

    // X6's decoded ATVV samples are much quieter than CoreAudio microphone
    // samples. This +20 dB calibration is inherited from the proven V1 path;
    // it is input calibration, not source priority.
    private static let remoteGain: Float = 10.0

    private let stateLock = NSLock()
    private var mixActive = false
    private var remoteInputEnabled = AppStorage.remoteInputEnabled
    private var outputDeviceID: AudioDeviceID?
    private var outputIOProcID: AudioDeviceIOProcID?

    private var pendingRemote: [Float] = []
    private var pendingRemoteIndex = 0

    private var scheduledRemoteBuffers = 0
    private var scheduledPeak: Float = 0
    private var renderCallbackCount = 0
    private var remoteSessionScheduledBuffers = 0
    private var remoteSessionRenderedFrames = 0
    private var loggedFirstRemoteRender = false
    private var diagnosticsTimer: Timer?

    var onRouteChanged: ((Bool) -> Void)?
    /// 遥控器音频第一次到达（本会话内）时回调，用于确认麦克风真的开麦。
    var onRemoteAudioArrived: (() -> Void)?

    private override init() {
        super.init()

        if let deviceID = Self.findOutputDevice(named: Self.targetDeviceName) {
            startOutputDevice(deviceID)
        } else {
            print(
                "[AUDIO] ⚠️ 找不到 \(Self.targetDeviceName)，" +
                "请确认 vRemoteDriver.driver 已安装"
            )
        }

        if ProcessInfo.processInfo.environment["MIA_DIAGNOSTICS"] == "1" {
            startDiagnosticsTimer()
        }
    }

    // MARK: - Public input API

    func feed(samples: [Int16], inputSampleRate: Double = 16_000) {
        guard !samples.isEmpty else { return }
        let state = inputState
        guard state.mixActive, state.remoteEnabled else { return }
        onRemoteAudioArrived?()
        let floatSamples = samples.map { sample -> Float in
            let amplified = Float(sample) / 32768.0 * Self.remoteGain
            return max(-1.0, min(1.0, amplified))
        }
        schedule(
            monoSamples: floatSamples,
            sampleRate: inputSampleRate
        )
    }

    /// Kept under the V1 method name so the proven X6 session state machine
    /// remains unchanged. `active` means the remote audio route is open.
    func setRemoteActive(_ active: Bool) {
        stateLock.lock()
        let changed = mixActive != active
        mixActive = active
        clearPendingBuffersLocked()
        if active, changed {
            remoteSessionScheduledBuffers = 0
            remoteSessionRenderedFrames = 0
            loggedFirstRemoteRender = false
        }
        stateLock.unlock()

        guard changed else { return }
        print(
            active
                ? "[AUDIO] 遥控器麦克风通路开启"
                : "[AUDIO] 遥控器麦克风通路关闭"
        )
        onRouteChanged?(active)
    }

    func setInputEnabled(remote: Bool) {
        stateLock.lock()
        let remoteChanged = remoteInputEnabled != remote
        remoteInputEnabled = remote
        if !remote {
            pendingRemote.removeAll(keepingCapacity: true)
            pendingRemoteIndex = 0
        }
        stateLock.unlock()

        AppStorage.remoteInputEnabled = remote

        if remoteChanged {
            print("[AUDIO] 遥控器输入更新 · \(remote ? "ON" : "OFF")")
            onRouteChanged?(mixActive)
        }
    }

    var isRemoteInputEnabled: Bool { inputState.remoteEnabled }
    var isOutputDeviceAvailable: Bool { outputDeviceID != nil }

    func stop() {
        diagnosticsTimer?.invalidate()
        diagnosticsTimer = nil

        if let deviceID = outputDeviceID, let ioProcID = outputIOProcID {
            let stopStatus = AudioDeviceStop(deviceID, ioProcID)
            let destroyStatus = AudioDeviceDestroyIOProcID(deviceID, ioProcID)
            print(
                "[AUDIO] vRemote IOProc 已释放: " +
                "stop=\(stopStatus), destroy=\(destroyStatus)"
            )
        }
        outputIOProcID = nil
        outputDeviceID = nil
    }

    // MARK: - Queues and resampling

    private var isMixActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return mixActive
    }

    private var inputState: (mixActive: Bool, remoteEnabled: Bool) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (mixActive, remoteInputEnabled)
    }

    private func schedule(
        monoSamples: [Float],
        sampleRate: Double
    ) {
        guard !monoSamples.isEmpty, sampleRate > 0 else { return }
        let resampled = Self.resample(
            monoSamples,
            from: sampleRate,
            to: Self.outputSampleRate
        )
        guard !resampled.isEmpty else { return }

        stateLock.lock()
        guard mixActive, remoteInputEnabled else {
            stateLock.unlock()
            return
        }

        var firstRemoteBufferDescription: String?
        compactRemoteBufferIfNeededLocked()
        pendingRemote.append(contentsOf: resampled)
        scheduledRemoteBuffers += 1
        remoteSessionScheduledBuffers += 1
        if remoteSessionScheduledBuffers == 1 {
            let peak = resampled.reduce(0) { max($0, abs($1)) }
            firstRemoteBufferDescription = String(
                format: "[AUDIO] X6 首缓冲 frames=%d peak=%.4f",
                resampled.count,
                peak
            )
        }
        scheduledPeak = max(
            scheduledPeak,
            resampled.reduce(0) { max($0, abs($1)) }
        )
        stateLock.unlock()

        if let firstRemoteBufferDescription {
            print(firstRemoteBufferDescription)
        }
    }

    private static func resample(
        _ input: [Float],
        from inputRate: Double,
        to outputRate: Double
    ) -> [Float] {
        if abs(inputRate - outputRate) < 1 {
            return input
        }
        let ratio = outputRate / inputRate
        let outputCount = max(1, Int((Double(input.count) * ratio).rounded(.down)))
        var output = [Float](repeating: 0, count: outputCount)
        for index in 0..<outputCount {
            let position = Double(index) / ratio
            let lower = min(Int(position), input.count - 1)
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(position - Double(lower))
            output[index] = input[lower] + (input[upper] - input[lower]) * fraction
        }
        return output
    }

    // MARK: - CoreAudio direct output

    private func startOutputDevice(_ deviceID: AudioDeviceID) {
        var ioProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(
            &ioProcID,
            deviceID,
            nil
        ) { [weak self] _, _, _, outputData, _ in
            self?.render(outputData)
        }
        guard createStatus == noErr, let ioProcID else {
            print("[AUDIO] ⚠️ 创建 vRemote IOProc 失败: OSStatus=\(createStatus)")
            return
        }

        let startStatus = AudioDeviceStart(deviceID, ioProcID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(deviceID, ioProcID)
            print("[AUDIO] ⚠️ 启动 vRemote IOProc 失败: OSStatus=\(startStatus)")
            return
        }

        outputDeviceID = deviceID
        outputIOProcID = ioProcID
        print("[AUDIO] vRemote IOProc 已启动: id=\(deviceID), 48000 Hz stereo")
    }

    private func render(_ outputData: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(outputData)
        guard let first = buffers.first else { return }
        let firstChannels = max(1, Int(first.mNumberChannels))
        let frameCount = Int(first.mDataByteSize) /
            MemoryLayout<Float>.size /
            firstChannels
        guard frameCount > 0 else { return }

        var remote = [Float](repeating: 0, count: frameCount)
        var mixed = [Float](repeating: 0, count: frameCount)
        var remoteTaken = 0
        var firstRemoteRenderDescription: String?

        stateLock.lock()
        if mixActive {
            let remoteAvailable = pendingRemote.count - pendingRemoteIndex
            if remoteAvailable > 0 {
                remoteTaken = min(frameCount, remoteAvailable)
                remote.replaceSubrange(
                    0..<remoteTaken,
                    with: pendingRemote[
                        pendingRemoteIndex..<(pendingRemoteIndex + remoteTaken)
                    ]
                )
                pendingRemoteIndex += remoteTaken
                remoteSessionRenderedFrames += remoteTaken
                if !loggedFirstRemoteRender {
                    loggedFirstRemoteRender = true
                    let peak = remote.reduce(0) { max($0, abs($1)) }
                    firstRemoteRenderDescription = String(
                        format: "[AUDIO] X6 首次输出 frames=%d peak=%.4f",
                        remoteTaken,
                        peak
                    )
                }
            }

            compactRemoteBufferIfNeededLocked()
        }
        renderCallbackCount += 1
        stateLock.unlock()

        if let firstRemoteRenderDescription {
            print(firstRemoteRenderDescription)
        }

        for frame in 0..<frameCount {
            let hasRemote = frame < remoteTaken
            let value: Float = hasRemote ? remote[frame] : 0
            mixed[frame] = max(-1.0, min(1.0, value))
        }

        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let channelCount = max(1, Int(buffer.mNumberChannels))
            let writableFrames = min(
                frameCount,
                Int(buffer.mDataByteSize) /
                    MemoryLayout<Float>.size /
                    channelCount
            )
            let output = data.assumingMemoryBound(to: Float.self)
            for frame in 0..<writableFrames {
                for channel in 0..<channelCount {
                    output[frame * channelCount + channel] = mixed[frame]
                }
            }
        }
    }

    private func clearPendingBuffersLocked() {
        pendingRemote.removeAll(keepingCapacity: true)
        pendingRemoteIndex = 0
    }

    private func compactRemoteBufferIfNeededLocked() {
        if pendingRemoteIndex > 4_096 {
            pendingRemote.removeFirst(pendingRemoteIndex)
            pendingRemoteIndex = 0
        }
        trimBufferIfNeededLocked(
            bufferCount: pendingRemote.count,
            index: &pendingRemoteIndex
        )
    }

    private func trimBufferIfNeededLocked(
        bufferCount: Int,
        index: inout Int
    ) {
        let maximumQueuedFrames = Int(Self.outputSampleRate * 2)
        let available = bufferCount - index
        if available > maximumQueuedFrames {
            index += available - maximumQueuedFrames
        }
    }

    private static func findOutputDevice(named targetName: String) -> AudioDeviceID? {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize
        ) == noErr else { return nil }

        let count = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize, &devices
        ) == noErr else { return nil }

        for id in devices where id != 0 {
            var nameRef: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(
                id, &nameAddress, 0, nil, &nameSize, &nameRef
            ) == noErr else { continue }
            guard let name = nameRef?.takeRetainedValue() as String? else { continue }
            if name.caseInsensitiveCompare(targetName) == .orderedSame {
                return id
            }
        }
        return nil
    }

    // MARK: - Diagnostics

    private func startDiagnosticsTimer() {
        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            self.stateLock.lock()
            let active = self.mixActive
            let remoteBuffers = self.scheduledRemoteBuffers
            let peak = self.scheduledPeak
            let renders = self.renderCallbackCount
            let remoteQueued = self.pendingRemote.count - self.pendingRemoteIndex
            self.scheduledRemoteBuffers = 0
            self.scheduledPeak = 0
            self.renderCallbackCount = 0
            self.stateLock.unlock()
            print(String(
                format:
                    "[AUDIO-METER] route=%@ remoteBuffers=%d " +
                    "remoteQueued=%d peak=%.4f renders=%d",
                active ? "on" : "off",
                remoteBuffers,
                remoteQueued,
                peak,
                renders
            ))
        }
    }
}
