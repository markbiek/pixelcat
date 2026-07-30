import AppKit

/// The bubble the animal speaks through: a borderless child window holding a
/// single view that draws a comic-style bubble with a tail pointing down at
/// the cat. Being a child window of CatWindow means AppKit moves it during
/// drags for free.
final class SpeechBubbleWindow: NSWindow {
    private let bubbleView = SpeechBubbleView()

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
    /// as a child window so dragging the cat drags the bubble.
    func show(text: String, above parent: NSWindow) {
        bubbleView.text = text
        let size = bubbleView.sizeThatFits(text)
        setFrame(
            NSRect(
                x: parent.frame.midX - size.width / 2,
                y: parent.frame.maxY - 6,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        if parent.childWindows?.contains(self) != true {
            parent.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    func hide() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
}

/// Draws the bubble itself. Sizing and drawing live together so the
/// paddings can't drift apart.
final class SpeechBubbleView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }

    private static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    private static let padding: CGFloat = 8
    private static let tailHeight: CGFloat = 8
    private static let maxTextWidth: CGFloat = 200
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
            x: 1,
            y: Self.tailHeight,
            width: bounds.width - 2,
            height: bounds.height - Self.tailHeight - 1
        )
        let bubble = NSBezierPath(roundedRect: body, xRadius: 4, yRadius: 4)
        bubble.lineWidth = 2

        NSColor.white.setFill()
        bubble.fill()
        NSColor.black.setStroke()
        bubble.stroke()

        // Tail: filled after the border so it visually merges with the body,
        // then just its two outer edges are stroked.
        let tail = NSBezierPath()
        let tailLeft = NSPoint(x: body.midX - 6, y: body.minY + 2)
        let tailTip = NSPoint(x: body.midX - 2, y: 0)
        let tailRight = NSPoint(x: body.midX + 6, y: body.minY + 2)
        tail.move(to: tailLeft)
        tail.line(to: tailTip)
        tail.line(to: tailRight)
        tail.close()
        NSColor.white.setFill()
        tail.fill()

        let outline = NSBezierPath()
        outline.lineWidth = 2
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
