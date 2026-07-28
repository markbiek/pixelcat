import Testing
import Foundation
@testable import PixelCatCore

private let valid: Set<String> = ["idle", "sleep", "dance"]

@Test func parsesAKnownStateName() {
    #expect(StateSignal.parse("dance", validStates: valid) == .state("dance"))
}

@Test func trimsSurroundingWhitespaceAndNewlines() {
    // `echo dance > file` leaves a trailing newline.
    #expect(StateSignal.parse("  dance\n", validStates: valid) == .state("dance"))
}

@Test func isCaseInsensitive() {
    #expect(StateSignal.parse("DANCE", validStates: valid) == .state("dance"))
}

@Test func recognizesTheAutoKeyword() {
    #expect(StateSignal.parse("auto\n", validStates: valid) == .auto)
}

@Test func returnsNilForAnEmptyFile() {
    #expect(StateSignal.parse("", validStates: valid) == nil)
    #expect(StateSignal.parse("   \n\n", validStates: valid) == nil)
}

@Test func returnsNilForAnUnknownStateName() {
    #expect(StateSignal.parse("zoomies", validStates: valid) == nil)
}

@Test func readsOnlyTheFirstLine() {
    // Guards against a file that accumulated extra content.
    #expect(StateSignal.parse("sleep\nleftover junk\n", validStates: valid) == .state("sleep"))
}

@Test func defaultFileURLPointsAtTheConfigDirectory() {
    let url = StateSignal.defaultFileURL
    #expect(url.lastPathComponent == "state")
    #expect(url.deletingLastPathComponent().lastPathComponent == "pixelcat")
}
