import CoreGraphics
import Testing
@testable import PixelCatCore

@Suite struct BubblePlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let text = CGSize(width: 150, height: 40)
    let tail: CGFloat = 8

    private func place(animal: CGRect) -> BubblePlacement {
        BubblePlacer.place(
            textSize: text,
            tailLength: tail,
            animal: animal,
            screen: screen
        )
    }

    @Test func sitsCenteredAboveWhenThereIsHeadroom() {
        let animal = CGRect(x: 400, y: 300, width: 72, height: 72)
        let placement = place(animal: animal)
        #expect(placement.tail == .bottom)
        #expect(placement.frame.midX == animal.midX)
        #expect(placement.frame.minY == animal.maxY - 6)
        #expect(placement.frame.size == CGSize(width: 150, height: 48))
    }

    @Test func clampsHorizontallyAtAVerticalEdge() {
        let animal = CGRect(x: 950, y: 300, width: 72, height: 72)
        let placement = place(animal: animal)
        #expect(placement.tail == .bottom)
        #expect(placement.frame.maxX == screen.maxX)
    }

    @Test func goesLeftWhenTheAnimalIsNearTheTopRight() {
        let animal = CGRect(x: 900, y: 720, width: 72, height: 72)
        let placement = place(animal: animal)
        #expect(placement.tail == .right)
        #expect(placement.frame.maxX == animal.minX + 6)
        #expect(placement.frame.midY == animal.midY)
        #expect(placement.frame.size == CGSize(width: 158, height: 40))
    }

    @Test func goesRightWhenTheAnimalIsNearTheTopLeft() {
        let animal = CGRect(x: 20, y: 720, width: 72, height: 72)
        let placement = place(animal: animal)
        #expect(placement.tail == .left)
        #expect(placement.frame.minX == animal.maxX - 6)
        #expect(placement.frame.midY == animal.midY)
    }

    @Test func picksTheRoomierSideAtTheTopMiddle() {
        // Slightly left of center: more room on the right.
        let animal = CGRect(x: 400, y: 720, width: 72, height: 72)
        #expect(place(animal: animal).tail == .left)
        // Slightly right of center: more room on the left.
        let shifted = CGRect(x: 600, y: 720, width: 72, height: 72)
        #expect(place(animal: shifted).tail == .right)
    }

    @Test func sideBubblesStayOnScreenVertically() {
        let animal = CGRect(x: 900, y: 780, width: 72, height: 72)
        let placement = place(animal: animal)
        #expect(placement.tail == .right)
        #expect(placement.frame.maxY <= screen.maxY)
    }

    @Test func respectsANonZeroScreenOrigin() {
        // visibleFrame origins are rarely (0,0) in production — the Dock
        // raises minY and display arrangement shifts minX.
        let shifted = CGRect(x: 100, y: 50, width: 1000, height: 800)
        // Above placement, animal tucked into the lower-left corner.
        let low = CGRect(x: 60, y: 20, width: 72, height: 72)
        let above = BubblePlacer.place(
            textSize: text, tailLength: tail, animal: low, screen: shifted
        )
        #expect(above.tail == .bottom)
        #expect(above.frame.minX >= shifted.minX)
        #expect(above.frame.minY >= shifted.minY)
        // Side placement, animal at the top edge below the screen's minY.
        let high = CGRect(x: 60, y: 810, width: 72, height: 72)
        let side = BubblePlacer.place(
            textSize: text, tailLength: tail, animal: high, screen: shifted
        )
        #expect(side.tail == .left)
        #expect(side.frame.minX >= shifted.minX)
        #expect(side.frame.maxY <= shifted.maxY)
    }

    @Test func fallsBackToClampedAboveWhenNothingFits() {
        let tiny = CGRect(x: 0, y: 0, width: 200, height: 100)
        let animal = CGRect(x: 60, y: 40, width: 72, height: 72)
        let placement = BubblePlacer.place(
            textSize: text,
            tailLength: tail,
            animal: animal,
            screen: tiny
        )
        #expect(placement.tail == .bottom)
        #expect(tiny.contains(placement.frame))
    }
}
