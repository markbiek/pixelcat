import Foundation

/// One thing the animal can say, optionally tied to a state.
///
/// The on-disk format is one phrase per line, with an optional `state: `
/// prefix. The tag is only recognized when the prefix is a single word:
/// a colon later in a sentence must not eat the phrase.
public struct Phrase: Equatable, Sendable {
    /// Bubbles are small; longer input is truncated rather than rejected so
    /// a generator that rambles still teaches *something*.
    public static let maxLength = 100

    public let stateTag: String?
    public let text: String

    public init(stateTag: String?, text: String) {
        self.stateTag = stateTag
        self.text = String(text.prefix(Phrase.maxLength))
    }

    /// The line form that `parse(line:)` reads back.
    public var line: String {
        stateTag.map { "\($0): \(text)" } ?? text
    }

    /// Returns nil for blank lines and for a tag with no text after it.
    public static func parse(line: String) -> Phrase? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let colon = trimmed.firstIndex(of: ":") {
            let prefix = String(trimmed[trimmed.startIndex..<colon])
            let remainder = String(trimmed[trimmed.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            let isSingleWord = !prefix.isEmpty
                && prefix.rangeOfCharacter(from: .whitespaces) == nil
            if isSingleWord {
                guard !remainder.isEmpty else { return nil }
                return Phrase(stateTag: prefix.lowercased(), text: remainder)
            }
        }
        return Phrase(stateTag: nil, text: trimmed)
    }
}

/// Parsing and selection over a list of phrases. Stateless: the caller owns
/// the list (it comes off disk fresh each time), these are just the rules.
public enum PhraseBook {
    public static func parse(_ contents: String) -> [Phrase] {
        contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { Phrase.parse(line: String($0)) }
    }

    /// Untagged phrases fit any moment; tagged ones only their state. A tag
    /// no state of the current animal uses simply never matches — same
    /// forgiving posture as the `state` signal file.
    public static func eligible(_ phrases: [Phrase], state: String) -> [Phrase] {
        phrases.filter { $0.stateTag == nil || $0.stateTag == state }
    }

    /// Picks by a value in 0..<1, mirroring `CatBrain.decide(roll:)` so
    /// selection is testable without a seeded generator.
    public static func pick(from phrases: [Phrase], state: String, roll: Double) -> Phrase? {
        let candidates = eligible(phrases, state: state)
        guard !candidates.isEmpty else { return nil }
        let clamped = min(max(roll, 0), 0.999999)
        return candidates[Int(clamped * Double(candidates.count))]
    }
}
