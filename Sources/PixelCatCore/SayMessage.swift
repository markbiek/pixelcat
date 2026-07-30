import Foundation

/// One message from the `say` file. The first non-empty line is spoken.
/// Lines after it may opt in to click behavior:
///
///     app: <name>            bring this app forward on click
///     run: /abs/path args…   execute this argv on click — no shell
///
/// Marked lines are honored wherever they appear after the first line,
/// and the first *accepted* line of each kind wins — a marked line that
/// fails validation leaves its slot open for a later one. Unmarked lines
/// are inert, so plain multi-line text relayed into the file gains no
/// behavior on its own.
public struct SayMessage: Equatable, Sendable {
    public static let appMarker = "app:"
    public static let runMarker = "run:"

    public let text: String
    public let clickApp: String?
    public let clickCommand: [String]?

    public init(text: String, clickApp: String?, clickCommand: [String]? = nil) {
        self.text = text
        self.clickApp = clickApp
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
        var app: String?
        var command: [String]?
        for line in lines.dropFirst() {
            if app == nil, line.hasPrefix(appMarker) {
                let body = line
                    .dropFirst(appMarker.count)
                    .trimmingCharacters(in: .whitespaces)
                // No slashes: `open -a` accepts paths as well as names,
                // and a path would let relayed text launch any bundle on
                // disk. Real app names never contain "/".
                app = body.isEmpty || body.contains("/") ? nil : body
            } else if command == nil, line.hasPrefix(runMarker) {
                command = parseCommand(line)
            }
        }
        return SayMessage(
            text: String(first.prefix(Phrase.maxLength)),
            clickApp: app,
            clickCommand: command
        )
    }

    /// Whitespace-split argv. The executable must be an absolute path —
    /// there is deliberately no shell and no PATH lookup, so relayed text
    /// containing `;`, `$()`, or quotes gets them as literal arguments.
    private static func parseCommand(_ line: String) -> [String]? {
        let tokens = line
            .dropFirst(runMarker.count)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard let executable = tokens.first, executable.hasPrefix("/") else {
            return nil
        }
        return tokens
    }
}
