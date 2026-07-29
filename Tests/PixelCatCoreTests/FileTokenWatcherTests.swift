import Testing
import Foundation
@testable import PixelCatCore

private let valid: Set<String> = ["cat", "dog", "bat"]

/// Grouped into a suite rather than left as free functions, which is this
/// target's usual style: three of these names — trimming, case, first line —
/// already exist as global test functions in StateSignalTests, and two global
/// functions cannot share a name in one module. The suite also gives
/// `swift test --filter FileTokenWatcherTests` something to match.
@Suite struct FileTokenWatcherTests {
    @Test func parsesAKnownToken() {
        #expect(FileTokenWatcher.parse("dog", validTokens: valid) == "dog")
    }

    @Test func trimsSurroundingWhitespaceAndNewlines() {
        #expect(FileTokenWatcher.parse("  dog\n", validTokens: valid) == "dog")
    }

    @Test func isCaseInsensitive() {
        #expect(FileTokenWatcher.parse("DOG", validTokens: valid) == "dog")
    }

    @Test func readsOnlyTheFirstLine() {
        #expect(FileTokenWatcher.parse("bat\nleftover junk\n", validTokens: valid) == "bat")
    }

    @Test func returnsNilForAnEmptyDocument() {
        #expect(FileTokenWatcher.parse("", validTokens: valid) == nil)
        #expect(FileTokenWatcher.parse("   \n\n", validTokens: valid) == nil)
    }

    @Test func returnsNilForAnUnknownToken() {
        #expect(FileTokenWatcher.parse("dinosaur", validTokens: valid) == nil)
    }
}
