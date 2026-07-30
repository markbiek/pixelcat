import AppKit
import PixelCatCore

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

    /// Whether a bubble is currently on screen. Callers use this to decide
    /// if a new message may replace what the viewer is still reading.
    var isShowingBubble: Bool { isVisible }

    /// Sizes to the text, places itself above or beside the parent (the
    /// placer keeps a big bubble from being clamped down over the animal),
    /// and attaches as a child window so dragging the cat drags the bubble.
    /// A bubble with an onClick action accepts clicks; without one it stays
    /// click-through so it never steals events from windows underneath.
    func show(text: String, above parent: NSWindow, onClick: (() -> Void)? = nil) {
        self.onClick = onClick
        ignoresMouseEvents = onClick == nil
        bubbleView.text = text
        // Without a screen to clamp to, a boundless rect keeps the
        // "above, centered" branch of the placer in charge.
        let visible = (parent.screen ?? NSScreen.main)?.visibleFrame
            ?? CGRect(x: -1e9, y: -1e9, width: 2e9, height: 2e9)
        let placement = BubblePlacer.place(
            textSize: bubbleView.textBlockSize(for: text),
            tailLength: SpeechBubbleView.tailHeight,
            animal: parent.frame,
            screen: visible
        )
        bubbleView.tail = placement.tail
        setFrame(placement.frame, display: true)
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

    /// Which edge the tail sticks out of; the window sets it from the
    /// placement so the tail always points at the animal.
    var tail: BubbleTail = .bottom {
        didSet { needsDisplay = true }
    }

    // The app is a background (menu bar) app, so the bubble is never in an
    // active application; without this the first click is swallowed as an
    // activation click and never reaches mouseDown.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    static let tailHeight: CGFloat = 8

    private static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    private static let padding: CGFloat = 8
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

    /// The bubble body needed for the text — padding included, tail
    /// excluded. The placer adds the tail on whichever edge it picks.
    func textBlockSize(for text: String) -> NSSize {
        let measured = (text as NSString).boundingRect(
            with: NSSize(width: Self.maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: Self.textAttributes
        )
        return NSSize(
            width: ceil(measured.width) + Self.padding * 2 + 4,
            height: ceil(measured.height) + Self.padding * 2 + 2
        )
    }

    private var bodyRect: NSRect {
        switch tail {
        case .bottom:
            NSRect(
                x: Self.borderInset,
                y: Self.tailHeight,
                width: bounds.width - Self.borderInset * 2,
                height: bounds.height - Self.tailHeight - Self.borderInset
            )
        case .left:
            NSRect(
                x: Self.tailHeight,
                y: Self.borderInset,
                width: bounds.width - Self.tailHeight - Self.borderInset,
                height: bounds.height - Self.borderInset * 2
            )
        case .right:
            NSRect(
                x: Self.borderInset,
                y: Self.borderInset,
                width: bounds.width - Self.tailHeight - Self.borderInset,
                height: bounds.height - Self.borderInset * 2
            )
        }
    }

    /// The tail triangle's three corners: two on the body edge, tip
    /// sticking out toward the animal.
    private var tailPoints: (base1: NSPoint, tip: NSPoint, base2: NSPoint) {
        let body = bodyRect
        switch tail {
        case .bottom:
            return (
                NSPoint(x: body.midX - Self.tailHalfWidth, y: body.minY + Self.tailTipXOffset),
                NSPoint(x: body.midX - Self.tailTipXOffset, y: 0),
                NSPoint(x: body.midX + Self.tailHalfWidth, y: body.minY + Self.tailTipXOffset)
            )
        case .left:
            return (
                NSPoint(x: body.minX + Self.tailTipXOffset, y: body.midY - Self.tailHalfWidth),
                NSPoint(x: 0, y: body.midY - Self.tailTipXOffset),
                NSPoint(x: body.minX + Self.tailTipXOffset, y: body.midY + Self.tailHalfWidth)
            )
        case .right:
            return (
                NSPoint(x: body.maxX - Self.tailTipXOffset, y: body.midY - Self.tailHalfWidth),
                NSPoint(x: bounds.maxX, y: body.midY - Self.tailTipXOffset),
                NSPoint(x: body.maxX - Self.tailTipXOffset, y: body.midY + Self.tailHalfWidth)
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = bodyRect
        let bubble = NSBezierPath(roundedRect: body, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        bubble.lineWidth = Self.borderWidth

        NSColor.white.setFill()
        bubble.fill()
        NSColor.black.setStroke()
        bubble.stroke()

        // Tail: filled after the border so it visually merges with the body,
        // then just its two outer edges are stroked.
        let points = tailPoints
        let tailPath = NSBezierPath()
        tailPath.move(to: points.base1)
        tailPath.line(to: points.tip)
        tailPath.line(to: points.base2)
        tailPath.close()
        NSColor.white.setFill()
        tailPath.fill()

        let outline = NSBezierPath()
        outline.lineWidth = Self.borderWidth
        outline.move(to: points.base1)
        outline.line(to: points.tip)
        outline.line(to: points.base2)
        NSColor.black.setStroke()
        outline.stroke()

        (text as NSString).draw(
            in: body.insetBy(dx: Self.padding, dy: Self.padding),
            withAttributes: Self.textAttributes
        )
    }
}
