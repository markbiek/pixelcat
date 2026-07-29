import Foundation

/// The phrase pool and its overnight backlog, as two plain-text files the
/// user can open and edit. Deliberately dumb about *when* things move —
/// OvernightLearning owns the schedule; this type only reads, appends,
/// and drains.
public struct PhraseStore: Sendable {
    public let poolURL: URL
    public let backlogURL: URL

    public init(directory: URL) {
        self.poolURL = directory.appendingPathComponent("phrases", isDirectory: false)
        self.backlogURL = directory.appendingPathComponent("backlog", isDirectory: false)
    }

    /// A missing or unreadable pool is an empty vocabulary, not an error —
    /// a cat with nothing to say is still a cat.
    public func loadPool() -> [Phrase] {
        guard let contents = try? String(contentsOf: poolURL, encoding: .utf8) else {
            return []
        }
        return PhraseBook.parse(contents)
    }

    /// Writes the starter vocabulary, but only when no pool file exists at
    /// all: an emptied file is a user's choice and stays empty.
    public func seedPoolIfMissing(_ starter: [Phrase]) throws {
        guard !FileManager.default.fileExists(atPath: poolURL.path) else { return }
        try FileManager.default.createDirectory(
            at: poolURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.serialize(starter).write(to: poolURL, atomically: true, encoding: .utf8)
    }

    public func appendToBacklog(_ phrases: [Phrase]) throws {
        guard !phrases.isEmpty else { return }
        try append(Self.serialize(phrases), to: backlogURL)
    }

    /// Moves everything in the backlog into the pool and returns what was
    /// learned. The backlog file is removed either way, so junk that parsed
    /// to nothing doesn't linger.
    public func drainBacklog() throws -> [Phrase] {
        guard let contents = try? String(contentsOf: backlogURL, encoding: .utf8) else {
            return []
        }
        let phrases = PhraseBook.parse(contents)
        if !phrases.isEmpty {
            try append(Self.serialize(phrases), to: poolURL)
        }
        try? FileManager.default.removeItem(at: backlogURL)
        return phrases
    }

    private static func serialize(_ phrases: [Phrase]) -> String {
        phrases.map(\.line).joined(separator: "\n") + "\n"
    }

    private func append(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(text.utf8))
        } else {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// The vocabulary a fresh install wakes up with. Tags use real state
    /// names from the bundled animals (cat: idle/sleep/dance, dog:
    /// idle/sleep/wag, bat: fly/hang/sleep); a tag the current animal
    /// doesn't have simply never fires.
    public static let starterPhrases: [Phrase] = [
        Phrase(stateTag: nil, text: "mew"),
        Phrase(stateTag: nil, text: "hello"),
        Phrase(stateTag: nil, text: "!"),
        Phrase(stateTag: "idle", text: "what's up"),
        Phrase(stateTag: "sleep", text: "zzz..."),
        Phrase(stateTag: "sleep", text: "five more minutes"),
        Phrase(stateTag: "dance", text: "watch this"),
        Phrase(stateTag: "wag", text: "hi hi hi hi"),
        Phrase(stateTag: "fly", text: "wheee"),
        Phrase(stateTag: "hang", text: "just hanging around"),
    ]
}
