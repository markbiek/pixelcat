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

    /// Regression test for watcher cross-talk.
    ///
    /// The directory watch fires for any entry change in the parent directory,
    /// and the app puts `state` and `animal` side by side, so before the inode
    /// check a write to one file made the other re-read and re-apply its own
    /// stale contents — writing `state` could silently switch the animal back.
    ///
    /// The three cases are deliberately checked together: suppressing the
    /// sibling event is only correct if the watcher still hears its own file
    /// afterwards, by both the file-source route (in-place write) and the
    /// directory route (replace-by-rename).
    @Test @MainActor func ignoresChangesToASiblingFileButHearsItsOwn() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pixelcat-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let watched = directory.appendingPathComponent("animal", isDirectory: false)
        let sibling = directory.appendingPathComponent("state", isDirectory: false)

        let log = TokenLog()
        let watcher = FileTokenWatcher(fileURL: watched, validTokens: valid) { token in
            log.tokens.append(token)
        }
        try watcher.start()
        defer { watcher.stop() }

        // Creating the watched file arrives via the directory watch.
        try "dog\n".write(to: watched, atomically: false, encoding: .utf8)
        await waitUntil { log.tokens == ["dog"] }

        // A sibling appearing changes the same directory entry. It is not ours.
        try "dance\n".write(to: sibling, atomically: false, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(400))
        #expect(log.tokens == ["dog"], "a sibling write must not re-deliver our token")

        // In-place write to our own file: arrives via the file watch.
        try "bat\n".write(to: watched, atomically: false, encoding: .utf8)
        await waitUntil { log.tokens == ["dog", "bat"] }

        // Replace-by-rename: a new inode, so the directory watch must act.
        let staging = directory.appendingPathComponent("staging", isDirectory: false)
        try "cat\n".write(to: staging, atomically: false, encoding: .utf8)
        // POSIX rename rather than FileManager.moveItem: it replaces the
        // destination atomically, which is what `mv` does and what the
        // directory watch exists to catch. moveItem refuses to overwrite.
        #expect(rename(staging.path, watched.path) == 0)
        await waitUntil { log.tokens == ["dog", "bat", "cat"] }
    }
}

/// Collects tokens on the main actor, matching the watcher's `@MainActor`
/// callback so the test needs no locking.
@MainActor
private final class TokenLog {
    var tokens: [String] = []
}

/// Polls rather than sleeping a fixed duration: passes as soon as the
/// condition holds, and only spends the full timeout when genuinely failing.
@MainActor
private func waitUntil(
    timeout: Duration = .seconds(3),
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("timed out waiting for the watcher to report")
}
