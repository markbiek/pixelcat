import Foundation

/// One message from the `say` file. The first non-empty line is spoken. A
/// second non-empty line starting with `run:` is a shell command to run if
/// the bubble is clicked. Everything else is ignored — execution is opt-in
/// by the writer, so multi-line text relayed into the file stays inert.
public struct SayMessage: Equatable, Sendable {
    public static let commandMarker = "run:"

    public let text: String
    public let clickCommand: String?

    public init(text: String, clickCommand: String?) {
        self.text = text
        self.clickCommand = clickCommand
    }

    /// Nil when there is nothing speakable. Text is capped at the same
    /// length as pool phrases.
    public static func parse(_ contents: String) -> SayMessage? {
        let lines = contents
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return nil }
        var command: String?
        if lines.count > 1, lines[1].hasPrefix(commandMarker) {
            let body = lines[1]
                .dropFirst(commandMarker.count)
                .trimmingCharacters(in: .whitespaces)
            command = body.isEmpty ? nil : body
        }
        return SayMessage(
            text: String(first.prefix(Phrase.maxLength)),
            clickCommand: command
        )
    }
}
