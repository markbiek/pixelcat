import Testing
import Foundation
@testable import PixelCatCore

private let validJSON = """
{
  "cellSize": 32,
  "scale": 3,
  "defaultState": "idle",
  "decideIntervalSeconds": [8, 20],
  "states": {
    "idle":  { "row": 0, "frames": 4, "fps": 4,  "weight": 70 },
    "sleep": { "row": 1, "frames": 2, "fps": 1,  "weight": 20 },
    "dance": { "row": 2, "frames": 6, "fps": 10, "weight": 10 }
  }
}
"""

@Test func decodesAValidManifest() throws {
    let manifest = try Manifest.decode(from: Data(validJSON.utf8))
    #expect(manifest.cellSize == 32)
    #expect(manifest.scale == 3)
    #expect(manifest.defaultState == "idle")
    #expect(manifest.states.count == 3)
    #expect(manifest.states["dance"]?.frames == 6)
    #expect(manifest.states["dance"]?.row == 2)
    #expect(manifest.decideInterval == 8.0...20.0)
}

@Test func rejectsADefaultStateThatDoesNotExist() {
    let json = validJSON.replacingOccurrences(
        of: #""defaultState": "idle""#,
        with: #""defaultState": "nope""#
    )
    #expect(throws: ManifestError.self) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func rejectsAStateWithZeroFrames() {
    let json = validJSON.replacingOccurrences(
        of: #""frames": 4"#,
        with: #""frames": 0"#
    )
    #expect(throws: ManifestError.self) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func rejectsAnIntervalWhoseBoundsAreInverted() {
    let json = validJSON.replacingOccurrences(
        of: "[8, 20]",
        with: "[20, 8]"
    )
    #expect(throws: ManifestError.self) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func rejectsAnEmptyStateTable() {
    let json = validJSON.replacingOccurrences(
        of: #""idle":  { "row": 0, "frames": 4, "fps": 4,  "weight": 70 },"#,
        with: ""
    ).replacingOccurrences(
        of: #""sleep": { "row": 1, "frames": 2, "fps": 1,  "weight": 20 },"#,
        with: ""
    ).replacingOccurrences(
        of: #""dance": { "row": 2, "frames": 6, "fps": 10, "weight": 10 }"#,
        with: ""
    ).replacingOccurrences(
        of: #""defaultState": "idle""#,
        with: #""defaultState": """#
    )
    #expect(throws: ManifestError.self) {
        try Manifest.decode(from: Data(json.utf8))
    }
}
