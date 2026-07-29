import Testing
import Foundation
@testable import PixelCatCore

@Suite struct PhraseStoreTests {
    /// Each test gets its own temp directory, same pattern as
    /// FileTokenWatcherTests.
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pixelcat-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func loadsAnEmptyPoolWhenTheFileIsMissing() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(PhraseStore(directory: dir).loadPool() == [])
    }

    @Test func seedsThePoolOnlyWhenMissing() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PhraseStore(directory: dir)
        let starter = [Phrase(stateTag: nil, text: "mew")]

        try store.seedPoolIfMissing(starter)
        #expect(store.loadPool() == starter)

        // A second seed must not clobber user edits.
        try "hello\n".write(to: store.poolURL, atomically: true, encoding: .utf8)
        try store.seedPoolIfMissing(starter)
        #expect(store.loadPool() == [Phrase(stateTag: nil, text: "hello")])
    }

    @Test func appendToBacklogAccumulatesAcrossCalls() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PhraseStore(directory: dir)

        try store.appendToBacklog([Phrase(stateTag: nil, text: "one")])
        try store.appendToBacklog([Phrase(stateTag: "sleep", text: "two")])

        let contents = try String(contentsOf: store.backlogURL, encoding: .utf8)
        #expect(PhraseBook.parse(contents) == [
            Phrase(stateTag: nil, text: "one"),
            Phrase(stateTag: "sleep", text: "two"),
        ])
    }

    @Test func drainMovesBacklogIntoPoolAndReturnsIt() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PhraseStore(directory: dir)
        try store.seedPoolIfMissing([Phrase(stateTag: nil, text: "mew")])
        try store.appendToBacklog([Phrase(stateTag: nil, text: "new thing")])

        let learned = try store.drainBacklog()

        #expect(learned == [Phrase(stateTag: nil, text: "new thing")])
        #expect(store.loadPool() == [
            Phrase(stateTag: nil, text: "mew"),
            Phrase(stateTag: nil, text: "new thing"),
        ])
        #expect(!FileManager.default.fileExists(atPath: store.backlogURL.path))
    }

    @Test func drainingAnEmptyBacklogIsANoOp() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PhraseStore(directory: dir)
        try store.seedPoolIfMissing([Phrase(stateTag: nil, text: "mew")])

        #expect(try store.drainBacklog() == [])
        #expect(store.loadPool() == [Phrase(stateTag: nil, text: "mew")])
    }

    @Test func starterPhrasesAreNonEmptyAndWithinTheCap() {
        #expect(!PhraseStore.starterPhrases.isEmpty)
        for phrase in PhraseStore.starterPhrases {
            #expect(phrase.text.count <= Phrase.maxLength)
        }
    }
}
