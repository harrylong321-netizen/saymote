import AppKit

/// 屏幕下方的临时提示浮层（toast）。
///
/// 用途：菜单栏图标在窗口很多时根本看不见，所以「遥控器没开麦」这类
/// 需要立刻被注意到的信息改成浮层显示。
///
/// 特性：不抢焦点、不响应鼠标、不进入 App 切换器；淡入 → 停留 2 秒 →
/// 淡出后自动关闭。
final class ToastPresenter {
    static let shared = ToastPresenter()

    private static let visibleDuration: TimeInterval = 2.0
    private static let fadeInDuration: TimeInterval = 0.18
    private static let fadeOutDuration: TimeInterval = 0.35
    /// 距屏幕可见区域底部的相对高度（0 = 贴底，1 = 贴顶）。
    private static let verticalPosition: CGFloat = 0.18

    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    private init() {}

    func show(_ text: String, symbolName: String = "exclamationmark.triangle.fill") {
        DispatchQueue.main.async { [weak self] in
            self?.present(text: text, symbolName: symbolName)
        }
    }

    private func present(text: String, symbolName: String) {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.close()
        panel = nil

        guard let screen = Self.targetScreen() else { return }

        let content = ToastContentView(text: text, symbolName: symbolName)
        let size = content.fittingSize
        guard size.width > 0, size.height > 0 else { return }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + visible.height * Self.verticalPosition
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.visibleDuration,
            execute: work
        )
    }

    private func dismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeOutDuration
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            panel.close()
            if self?.panel === panel { self?.panel = nil }
        }
    }

    /// 多屏时跟随鼠标所在的屏幕，用户正在看哪块屏就显示在哪块。
    private static func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        let containing = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        return containing ?? NSScreen.main ?? NSScreen.screens.first
    }
}

private final class ToastContentView: NSView {
    init(text: String, symbolName: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.07, alpha: 0.94).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 1, alpha: 0.14).cgColor

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        icon.contentTintColor = .systemOrange
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 17,
            weight: .semibold
        )
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
        ])

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [icon, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
