import Testing
import Foundation
@testable import PixelCatCore

@Test func decodesGeometryFromAFlatDocument() throws {
    let json = #"{ "cellSize": 24, "scale": 3, "defaultAnimal": "cat" }"#
    let geometry = try JSONDecoder().decode(SpriteGeometry.self, from: Data(json.utf8))
    #expect(geometry.cellSize == 24)
    #expect(geometry.scale == 3)
}

@Test func rejectsNonPositiveCellSize() {
    let geometry = SpriteGeometry(cellSize: 0, scale: 3)
    #expect(throws: GeometryError.invalid("cellSize must be positive, got 0")) {
        try geometry.validate()
    }
}

@Test func rejectsScaleBelowOne() {
    let geometry = SpriteGeometry(cellSize: 24, scale: 0)
    #expect(throws: GeometryError.invalid("scale must be at least 1, got 0")) {
        try geometry.validate()
    }
}

@Test func acceptsValidGeometry() throws {
    try SpriteGeometry(cellSize: 24, scale: 3).validate()
}
