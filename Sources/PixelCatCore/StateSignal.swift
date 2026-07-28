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

    /// Interprets the contents of the signal file. Returns nil for anything
    /// empty or unrecognized, which callers treat as "leave the cat alone".
    public static func parse(_ contents: String, validStates: Set<String>) -> StateRequest? {
        let firstLine = contents.split(
            separator: "\n",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).first.map(String.init) ?? ""

        let token = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if token.isEmpty { return nil }
        if token == "auto" { return .auto }
        return validStates.contains(token) ? .state(token) : nil
    }
}

/// Watches the signal file's directory and reports state requests.
///
/// Binds to the directory rather than the file so that replace-by-rename —
/// what most editors and `mv` do — does not silently kill the watch.
public final class StateSignalWatcher {
    private let fileURL: URL
    private let directoryURL: URL
    private let validStates: Set<String>
    private let onRequest: @MainActor (StateRequest) -> Void
    private let queue = DispatchQueue(label: "com.markbiek.pixelcat.signal")

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var pending: DispatchWorkItem?

    public init(
        fileURL: URL = StateSignal.defaultFileURL,
        validStates: Set<String>,
        onRequest: @escaping @MainActor (StateRequest) -> Void
    ) {
        self.fileURL = fileURL
        self.directoryURL = fileURL.deletingLastPathComponent()
        self.validStates = validStates
        self.onRequest = onRequest
    }

    public func start() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            throw StateSignalError.cannotWatch(
                path: directoryURL.path,
                errno: String(cString: strerror(errno))
            )
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleRead()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }
        source.resume()
        self.source = source
    }

    public func stop() {
        // `pending` is also mutated by `scheduleRead()` on `queue`; route this
        // mutation through the same queue rather than touching it from the
        // caller's thread.
        queue.sync {
            pending?.cancel()
            pending = nil
        }
        source?.cancel()
        source = nil
    }

    /// A single write can produce several filesystem events. Coalesce them.
    private func scheduleRead() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.readAndReport()
        }
        pending = work
        queue.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func readAndReport() {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }
        guard let request = StateSignal.parse(contents, validStates: validStates) else {
            FileHandle.standardError.write(Data(
                "pixelcat: ignoring unrecognized signal in \(fileURL.path)\n".utf8
            ))
            return
        }
        let callback = onRequest
        Task { @MainActor in
            callback(request)
        }
    }
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
