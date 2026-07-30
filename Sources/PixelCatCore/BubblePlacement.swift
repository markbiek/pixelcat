import CoreGraphics

/// Which bubble edge carries the tail pointing at the animal.
public enum BubbleTail: Equatable, Sendable {
    case bottom, left, right
}

public struct BubblePlacement: Equatable, Sendable {
    public let frame: CGRect
    public let tail: BubbleTail

    public init(frame: CGRect, tail: BubbleTail) {
        self.frame = frame
        self.tail = tail
    }
}

/// Decides where the speech bubble goes relative to the animal: above by
/// preference, beside it when the screen edge leaves no headroom — so a
/// large bubble near the top of the screen sits next to the animal
/// instead of being clamped down on top of it.
public enum BubblePlacer {
    /// - Parameters:
    ///   - textSize: the bubble body (text plus padding), tail excluded.
    ///   - tailLength: how far the tail sticks out of the body.
    ///   - animal: the animal window's frame.
    ///   - screen: the visible screen area to stay within.
    ///   - overlap: how far the tail side reaches back over the animal's
    ///     frame so the tail tip visually touches it.
    public static func place(
        textSize: CGSize,
        tailLength: CGFloat,
        animal: CGRect,
        screen: CGRect,
        overlap: CGFloat = 6
    ) -> BubblePlacement {
        let aboveSize = CGSize(
            width: textSize.width,
            height: textSize.height + tailLength
        )
        let aboveY = animal.maxY - overlap
        let clampedX = min(
            max(animal.midX - aboveSize.width / 2, screen.minX),
            screen.maxX - aboveSize.width
        )
        if aboveY + aboveSize.height <= screen.maxY {
            return BubblePlacement(
                frame: CGRect(origin: CGPoint(x: clampedX, y: aboveY), size: aboveSize),
                tail: .bottom
            )
        }

        // No headroom: try beside the animal, tail on the edge facing it.
        let sideSize = CGSize(
            width: textSize.width + tailLength,
            height: textSize.height
        )
        let sideY = min(
            max(animal.midY - sideSize.height / 2, screen.minY),
            screen.maxY - sideSize.height
        )
        let leftX = animal.minX - sideSize.width + overlap
        let rightX = animal.maxX - overlap
        let leftFits = leftX >= screen.minX
        let rightFits = rightX + sideSize.width <= screen.maxX
        let roomLeft = animal.minX - screen.minX
        let roomRight = screen.maxX - animal.maxX
        if leftFits && (!rightFits || roomLeft >= roomRight) {
            return BubblePlacement(
                frame: CGRect(origin: CGPoint(x: leftX, y: sideY), size: sideSize),
                tail: .right
            )
        }
        if rightFits {
            return BubblePlacement(
                frame: CGRect(origin: CGPoint(x: rightX, y: sideY), size: sideSize),
                tail: .left
            )
        }

        // Nowhere fits cleanly; clamp onto the screen above the animal.
        let clampedY = min(max(aboveY, screen.minY), screen.maxY - aboveSize.height)
        return BubblePlacement(
            frame: CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: aboveSize),
            tail: .bottom
        )
    }
}
