import CoreGraphics
import Foundation

/// 豆包语音输入的触发键。
///
/// **必须区分左右**：豆包输入法里配置快捷键是分左右键的，而 macOS 的键码
/// 并不是「左小右大」——左 ⌘ = 0x37、右 ⌘ = 0x36。早期版本把左右两个键码
/// 放在一起、用 `min()` 取「主键」，结果 Command 取到了**右** ⌘，和豆包
/// 里设的「左 ⌘」对不上，表现为按遥控器唤不醒豆包。所以这里一个键一个 case，
/// 键码写死，不做任何推断。
///
/// 只保留 Command / Option / Control：Shift 与 Fn 在豆包里会与输入法自身的
/// 快捷键冲突，实测无用；Control 也不给「右」——MacBook 键盘压根没有右 ⌃。
enum InputTriggerKey: String, CaseIterable, Identifiable {
    case leftCommand
    case rightCommand
    case leftOption
    case rightOption
    case leftControl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftCommand: L10n.text("左 Command (⌘)", "Left Command (⌘)")
        case .rightCommand: L10n.text("右 Command (⌘)", "Right Command (⌘)")
        case .leftOption: L10n.text("左 Option (⌥)", "Left Option (⌥)")
        case .rightOption: L10n.text("右 Option (⌥)", "Right Option (⌥)")
        case .leftControl: L10n.text("左 Control (⌃)", "Left Control (⌃)")
        }
    }

    /// 键码写死，一个 case 一个键。别再合并左右、也别用 min()/max() 推。
    var keyCodes: Set<Int64> {
        switch self {
        case .leftCommand: [0x37]
        case .rightCommand: [0x36]
        case .leftOption: [0x3A]
        case .rightOption: [0x3D]
        case .leftControl: [0x3B]
        }
    }

    var primaryKeyCode: CGKeyCode {
        CGKeyCode(keyCodes.first ?? 0x3A)
    }

    var flag: CGEventFlags {
        switch self {
        case .leftCommand, .rightCommand: .maskCommand
        case .leftOption, .rightOption: .maskAlternate
        case .leftControl: .maskControl
        }
    }

    /// 旧版本只存 option / command / control（不分左右），而旧版实际发出去的
    /// 是「右 ⌘ / 左 ⌥ / 左 ⌃」（就是当年 min() 的结果）。按这个对应关系迁移，
    /// 升级后行为与升级前一致，用户不会觉得"换了个版本就变了"。
    static func migrated(fromLegacy raw: String) -> InputTriggerKey? {
        switch raw {
        case "command": return .rightCommand
        case "option": return .leftOption
        case "control", "rightControl": return .leftControl   // 右 ⌃ 已去掉（MacBook 没有右 ⌃）
        default: return nil
        }
    }
}

enum Key {
    /// Lets the event tap distinguish vRemoter-generated events from physical
    /// keyboards, Bluetooth buttons, and external remappers.
    static let syntheticMarker: Int64 = 0x4D_49_52_42 // "MIRB"

    static func triggerDown(_ trigger: InputTriggerKey = AppStorage.inputTriggerKey) {
        post(trigger: trigger, keyDown: true)
    }

    static func triggerUp(_ trigger: InputTriggerKey = AppStorage.inputTriggerKey) {
        post(trigger: trigger, keyDown: false)
    }

    /// A deliberate short modifier click for Doubao's toggle mode.
    static func triggerTap(
        _ trigger: InputTriggerKey = AppStorage.inputTriggerKey,
        completion: (() -> Void)? = nil
    ) {
        triggerDown(trigger)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            triggerUp(trigger)
            completion?()
        }
    }

    private static func post(trigger: InputTriggerKey, keyDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: trigger.primaryKeyCode,
            keyDown: keyDown
        ) else { return }
        event.flags = keyDown ? trigger.flag : []
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
        print(
            "[KEY] synthetic \(trigger.title) " +
            (keyDown ? "DOWN" : "UP")
        )
    }
}
