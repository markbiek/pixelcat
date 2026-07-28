import AppKit

final class CatWindow: NSWindow {
    init(side: CGFloat) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: side, height: side),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }

    /// Places the cat in the lower right of the main screen, inset from the edges.
    static func defaultOrigin(side: CGFloat) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.maxX - side - 64,
            y: visible.minY + 64
        )
    }
}
