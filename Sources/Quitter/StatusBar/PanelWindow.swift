import AppKit

/// Borderless, non-activating panel that hangs below the status item.
/// It is key-capable so the search field takes typing without activating Quitter.
@MainActor
final class PanelWindow: NSPanel {
    /// Screen-space point the panel's top edge is centred on.
    private var topCenter: NSPoint = .zero
    private var contentHeight: CGFloat = 200
    private(set) var isClosing = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Tokens.Size.panelWidth, height: 200),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        animationBehavior = .none
    }

    /// Clips the content to the panel's rounded shape so the window's alpha mask (and
    /// therefore its shadow and border) is rounded, not rectangular.
    func setRootView(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = Tokens.Radius.panel
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Called by the SwiftUI root whenever its ideal height changes.
    func setContentHeight(_ height: CGFloat) {
        let clamped = min(max(height, 1), Tokens.Size.panelMaxHeight)
        guard abs(clamped - contentHeight) > 0.5 else { return }
        contentHeight = clamped
        if isVisible && !isClosing {
            setFrame(targetFrame(), display: true)
            invalidateShadow()
        }
    }

    func present(topCenter: NSPoint) {
        self.topCenter = topCenter
        isClosing = false
        let final = targetFrame()
        setFrame(final.offsetBy(dx: 0, dy: Tokens.Motion.panelSlide), display: false)
        alphaValue = 0
        orderFrontRegardless()
        makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Tokens.Motion.panelFade
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(final, display: true)
        }
        invalidateShadow()
    }

    func dismiss(completion: @escaping @MainActor () -> Void = {}) {
        guard isVisible, !isClosing else { return }
        isClosing = true
        let target = frame.offsetBy(dx: 0, dy: Tokens.Motion.panelSlide)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Tokens.Motion.panelFade
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrame(target, display: true)
        } completionHandler: {
            MainActor.assumeIsolated {
                guard self.isClosing else { return }
                self.orderOut(nil)
                self.isClosing = false
                completion()
            }
        }
    }

    private func targetFrame() -> NSRect {
        NSRect(
            x: (topCenter.x - Tokens.Size.panelWidth / 2).rounded(),
            y: (topCenter.y - contentHeight).rounded(),
            width: Tokens.Size.panelWidth,
            height: contentHeight
        )
    }
}
