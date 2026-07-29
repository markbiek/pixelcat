import Testing
import Foundation
@testable import PixelCatCore

private let validJSON = """
{
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
    #expect(throws: ManifestError.unknownDefaultState("nope")) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func rejectsAStateWithZeroFrames() {
    let json = validJSON.replacingOccurrences(
        of: #""frames": 4"#,
        with: #""frames": 0"#
    )
    #expect(throws: ManifestError.invalidState(name: "idle", reason: "frames must be at least 1")) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func rejectsAnIntervalWhoseBoundsAreInverted() {
    let json = validJSON.replacingOccurrences(
        of: "[8, 20]",
        with: "[20, 8]"
    )
    #expect(throws: ManifestError.invalidInterval("expected 0 < min <= max, got 20.0 and 8.0")) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func rejectsAnEmptyStateTable() {
    // Leaves `defaultState` as "idle" untouched: `validate()` checks
    // emptyStates before unknownDefaultState, so this isolates the
    // empty-table condition rather than also proving the defaultState guard.
    let json = validJSON.replacingOccurrences(
        of: #""idle":  { "row": 0, "frames": 4, "fps": 4,  "weight": 70 },"#,
        with: ""
    ).replacingOccurrences(
        of: #""sleep": { "row": 1, "frames": 2, "fps": 1,  "weight": 20 },"#,
        with: ""
    ).replacingOccurrences(
        of: #""dance": { "row": 2, "frames": 6, "fps": 10, "weight": 10 }"#,
        with: ""
    )
    #expect(throws: ManifestError.emptyStates) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func missingDefaultStateFailsToDecode() {
    let json = validJSON.replacingOccurrences(
        of: #""defaultState": "idle","#,
        with: ""
    )
    #expect(throws: DecodingError.self) {
        try Manifest.decode(from: Data(json.utf8))
    }
}

@Test func orderedStateNamesIsSorted() throws {
    let manifest = try Manifest.decode(from: Data(validJSON.utf8))
    #expect(manifest.orderedStateNames == ["dance", "idle", "sleep"])
}
