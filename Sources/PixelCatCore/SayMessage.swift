import Foundation

/// One message from the `say` file. The first non-empty line is spoken. A
/// second non-empty line starting with `app:` names an application to
/// bring forward if the bubble is clicked. Everything else is ignored —
/// the behavior is opt-in by the writer, so multi-line text relayed into
/// the file stays inert.
public struct SayMessage: Equatable, Sendable {
    public static let appMarker = "app:"

    public let text: String
    public let clickApp: String?

    public init(text: String, clickApp: String?) {
        self.text = text
        self.clickApp = clickApp
    }

    /// Nil when there is nothing speakable. Text is capped at the same
    /// length as pool phrases.
    public static func parse(_ contents: String) -> SayMessage? {
        let lines = contents
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return nil }
        var app: String?
        if lines.count > 1, lines[1].hasPrefix(appMarker) {
            let body = lines[1]
                .dropFirst(appMarker.count)
                .trimmingCharacters(in: .whitespaces)
            // No slashes: `open -a` accepts paths as well as names, and a
            // path would let relayed text launch any bundle on disk. Real
            // app names never contain "/".
            app = body.isEmpty || body.contains("/") ? nil : body
        }
        return SayMessage(
            text: String(first.prefix(Phrase.maxLength)),
            clickApp: app
        )
    }
}
