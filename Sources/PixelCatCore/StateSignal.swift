import Foundation

public enum StateRequest: Equatable, Sendable {
    case state(String)
    case auto
}

public enum StateSignal {
    /// `~/.config/pixelcat/state`
    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("pixelcat", isDirectory: true)
            .appendingPathComponent("state", isDirectory: false)
    }

    /// The one place a token is given its state meaning. `auto` is the only
    /// word that means something other than "pin this state", and it is
    /// meaningful for states and not for animals, which is why it lives here
    /// rather than in the shared parser.
    static func request(for token: String) -> StateRequest {
        token == "auto" ? .auto : .state(token)
    }

    /// Interprets the contents of the signal file. Returns nil for anything
    /// empty or unrecognized, which callers treat as "leave the cat alone".
    public static func parse(_ contents: String, validStates: Set<String>) -> StateRequest? {
        var tokens = validStates
        tokens.insert("auto")
        guard let token = FileTokenWatcher.parse(contents, validTokens: tokens) else {
            return nil
        }
        return request(for: token)
    }
}

/// Watches the state file and reports state requests.
///
/// A thin adapter over FileTokenWatcher: the kqueue machinery is shared with
/// the animal file, and this type adds only the `auto` keyword, which is
/// meaningful for states and not for animals.
public final class StateSignalWatcher {
    private let inner: FileTokenWatcher

    public init(
        fileURL: URL = StateSignal.defaultFileURL,
        validStates: Set<String>,
        onRequest: @escaping @MainActor (StateRequest) -> Void
    ) {
        var tokens = validStates
        tokens.insert("auto")
        self.inner = FileTokenWatcher(
            fileURL: fileURL,
            validTokens: tokens
        ) { token in
            onRequest(StateSignal.request(for: token))
        }
    }

    public func start() throws { try inner.start() }
    public func stop() { inner.stop() }
}

public enum StateSignalError: Error, CustomStringConvertible {
    case cannotWatch(path: String, errno: String)

    public var description: String {
        switch self {
        case .cannotWatch(let path, let errno):
            return "cannot watch \(path): \(errno)"
        }
    }
}
