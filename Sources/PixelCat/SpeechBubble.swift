import AppKit

/// The bubble the animal speaks through: a borderless child window holding a
/// single view that draws a comic-style bubble with a tail pointing down at
/// the cat. Being a child window of CatWindow means AppKit moves it during
/// drags for free.
final class SpeechBubbleWindow: NSWindow {
    private let bubbleView = SpeechBubbleView()
    private var onClick: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        contentView = bubbleView
    }

    /// Sizes to the text, positions centered above the parent, and attaches
    /// as a child window so dragging the cat drags the bubble. A bubble with
    /// an onClick action accepts clicks; without one it stays click-through
    /// so it never steals events from windows underneath.
    func show(text: String, above parent: NSWindow, onClick: (() -> Void)? = nil) {
        self.onClick = onClick
        ignoresMouseEvents = onClick == nil
        bubbleView.text = text
        let size = bubbleView.sizeThatFits(text)
        var origin = NSPoint(
            x: parent.frame.midX - size.width / 2,
            y: parent.frame.maxY - 6
        )
        // A cat dragged to a screen edge would otherwise push the bubble
        // partway off-screen; clamp to the parent's own screen.
        if let visible = (parent.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        setFrame(
            NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height),
            display: true
        )
        if parent.childWindows?.contains(self) != true {
            parent.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    func hide() {
        onClick = nil
        parent?.removeChildWindow(self)
        orderOut(nil)
    }

    // Reaches us via the responder chain: SpeechBubbleView doesn't handle
    // mouseDown, so a click anywhere on the bubble lands here.
    override func mouseDown(with event: NSEvent) {
        guard let action = onClick else { return }
        hide()
        action()
    }
}

/// Draws the bubble itself. Sizing and drawing live together so the
/// paddings can't drift apart.
final class SpeechBubbleView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }

    // The app is a background (menu bar) app, so the bubble is never in an
    // active application; without this the first click is swallowed as an
    // activation click and never reaches mouseDown.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    private static let padding: CGFloat = 8
    private static let tailHeight: CGFloat = 8
    private static let maxTextWidth: CGFloat = 200
    private static let borderWidth: CGFloat = 2
    private static let cornerRadius: CGFloat = 4
    private static let borderInset: CGFloat = 1
    private static let tailHalfWidth: CGFloat = 6
    private static let tailTipXOffset: CGFloat = 2
    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
    ]

    func sizeThatFits(_ text: String) -> NSSize {
        let measured = (text as NSString).boundingRect(
            with: NSSize(width: Self.maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: Self.textAttributes
        )
        return NSSize(
            width: ceil(measured.width) + Self.padding * 2 + 4,
            height: ceil(measured.height) + Self.padding * 2 + Self.tailHeight + 2
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = NSRect(
            x: Self.borderInset,
            y: Self.tailHeight,
            width: bounds.width - Self.borderInset * 2,
            height: bounds.height - Self.tailHeight - Self.borderInset
        )
        let bubble = NSBezierPath(roundedRect: body, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        bubble.lineWidth = Self.borderWidth

        NSColor.white.setFill()
        bubble.fill()
        NSColor.black.setStroke()
        bubble.stroke()

        // Tail: filled after the border so it visually merges with the body,
        // then just its two outer edges are stroked.
        let tail = NSBezierPath()
        let tailLeft = NSPoint(x: body.midX - Self.tailHalfWidth, y: body.minY + Self.tailTipXOffset)
        let tailTip = NSPoint(x: body.midX - Self.tailTipXOffset, y: 0)
        let tailRight = NSPoint(x: body.midX + Self.tailHalfWidth, y: body.minY + Self.tailTipXOffset)
        tail.move(to: tailLeft)
        tail.line(to: tailTip)
        tail.line(to: tailRight)
        tail.close()
        NSColor.white.setFill()
        tail.fill()

        let outline = NSBezierPath()
        outline.lineWidth = Self.borderWidth
        outline.move(to: tailLeft)
        outline.line(to: tailTip)
        outline.line(to: tailRight)
        NSColor.black.setStroke()
        outline.stroke()

        (text as NSString).draw(
            in: body.insetBy(dx: Self.padding, dy: Self.padding),
            withAttributes: Self.textAttributes
        )
    }
}
