import AppKit

final class CatView: NSView {
    private var image: NSImage
    private var sourceRect: CGRect

    init(image: NSImage, sourceRect: CGRect, side: CGFloat) {
        self.image = image
        self.sourceRect = sourceRect
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    func update(image: NSImage, sourceRect: CGRect) {
        self.image = image
        self.sourceRect = sourceRect
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Without this the upscaled pixel art is smoothed into mush.
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(
            in: bounds,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0
        )
    }
}
