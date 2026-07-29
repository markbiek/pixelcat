import Testing
import Foundation
@testable import PixelCatCore

private func makeGeometry(cellSize: Int = 32) -> SpriteGeometry {
    SpriteGeometry(cellSize: cellSize, scale: 3)
}

private func makeManifest(
    states: [String: StateDefinition] = [
        "idle":  StateDefinition(row: 0, frames: 4, fps: 4,  weight: 70),
        "sleep": StateDefinition(row: 1, frames: 2, fps: 1,  weight: 20),
        "dance": StateDefinition(row: 2, frames: 6, fps: 10, weight: 10),
    ]
) -> Manifest {
    Manifest(
        defaultState: "idle",
        decideIntervalSeconds: [8, 20],
        states: states
    )
}

// Sheet is 6 columns by 3 rows of 32px cells.
private let sheetSize = CGSize(width: 192, height: 96)

@Test func topRowMapsToTheTopOfTheImage() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    // Row 0 is the top row, so in bottom-left coordinates its y is
    // height - (0 + 1) * 32 = 64.
    #expect(try sheet.frameRect(state: "idle", frame: 0)
            == CGRect(x: 0, y: 64, width: 32, height: 32))
}

@Test func bottomRowMapsToTheBottomOfTheImage() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    // Row 2 is the last of three rows, so its y is 96 - 3 * 32 = 0.
    #expect(try sheet.frameRect(state: "dance", frame: 0)
            == CGRect(x: 0, y: 0, width: 32, height: 32))
}

@Test func frameIndexAdvancesAlongTheXAxis() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    #expect(try sheet.frameRect(state: "dance", frame: 5)
            == CGRect(x: 160, y: 0, width: 32, height: 32))
}

@Test func frameIndexWrapsWithinTheState() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    // sleep has 2 frames, so frame 3 is frame 1.
    #expect(try sheet.frameRect(state: "sleep", frame: 3)
            == sheet.frameRect(state: "sleep", frame: 1))
}

@Test func everyFrameLandsInsideTheSheet() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    let bounds = CGRect(origin: .zero, size: sheetSize)
    for name in sheet.manifest.orderedStateNames {
        for frame in 0..<sheet.manifest.states[name]!.frames {
            let rect = try sheet.frameRect(state: name, frame: frame)
            #expect(bounds.contains(rect), "\(name) frame \(frame) fell outside the sheet")
        }
    }
}

@Test func rejectsASheetTooNarrowForItsFrames() {
    // dance claims 6 frames, which needs 192px, but this sheet is 128 wide.
    #expect(throws: SpriteSheetError.self) {
        try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: CGSize(width: 128, height: 96))
    }
}

@Test func rejectsASheetTooShortForItsRows() {
    // dance sits on row 2, which needs 96px of height.
    #expect(throws: SpriteSheetError.self) {
        try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: CGSize(width: 192, height: 64))
    }
}

@Test func rejectsAnUnknownStateName() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    #expect(throws: SpriteSheetError.self) {
        try sheet.frameRect(state: "zoomies", frame: 0)
    }
}

@Test func windowSideIsCellSizeTimesScale() throws {
    let sheet = try SpriteSheet(geometry: makeGeometry(), manifest: makeManifest(), sheetSize: sheetSize)
    #expect(sheet.windowSide == 96)
}
