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

/// Watches the signal file for state requests.
///
/// Runs two watches side by side:
/// - a **directory** watch (binds to the parent directory, not the file),
///   which survives replace-by-rename — what most editors and `mv` do —
///   because the directory entry itself changes on create/rename/delete;
/// - a **file** watch (binds to the file's own descriptor), which catches
///   in-place writes (`echo x > file`) that truncate and rewrite the
///   existing inode without touching the directory entry at all, so the
///   directory watch alone never sees them.
///
/// Neither watch alone is sufficient; together they cover create, in-place
/// write, replace-by-rename, and delete.
public final class StateSignalWatcher {
    private let fileURL: URL
    private let directoryURL: URL
    private let validStates: Set<String>
    private let onRequest: @MainActor (StateRequest) -> Void
    private let queue = DispatchQueue(label: "com.markbiek.pixelcat.signal")

    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
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

        let descriptor = open(directoryURL.path, O_EVTONLY)
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
            // The directory entry changed (create, rename-into, or delete).
            // Re-arm the file watch against whatever exists at `fileURL`
            // now, then treat this as a potential content change too.
            self?.armFileWatch()
            self?.scheduleRead()
        }
        // Capture `descriptor` by value rather than reading a stored property:
        // `cancel()` is asynchronous, so if `start()` runs again before this
        // handler fires, a property read here could close the new fd instead
        // of the one this source owns. Closing the captured value always
        // closes exactly the fd this source was created with.
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        directorySource = source

        // Also arm the file watch directly, in case the file already exists
        // from a previous session. This only wires up events - it does not
        // read the file's contents, so it does not violate the no-read-at-
        // launch decision: a stale signal from a previous session still has
        // no effect until something writes to the file again.
        queue.sync {
            armFileWatch()
        }
    }

    public func stop() {
        // `pending` and `fileSource` are also mutated on `queue` (by
        // scheduleRead() and armFileWatch(), invoked from the two sources'
        // event handlers, which run on `queue`); route these mutations
        // through the same queue rather than touching them from the
        // caller's thread. `directorySource` is only ever touched by
        // start()/stop(), both on the caller's thread, so it needs no such
        // routing.
        queue.sync {
            pending?.cancel()
            pending = nil
            fileSource?.cancel()
            fileSource = nil
        }
        directorySource?.cancel()
        directorySource = nil
    }

    /// Arms (or re-arms) a watch on the state file's own descriptor, so
    /// in-place writes are caught even though they never touch the
    /// directory entry.
    ///
    /// Must run on `queue`: it mutates `fileSource`, which the file source's
    /// own event handler also mutates (see below), and which `stop()`
    /// mutates via `queue.sync`. Callers already on `queue` (the directory
    /// watch's event handler) call it directly; `start()` calls it via
    /// `queue.sync`.
    ///
    /// Unconditionally replaces any existing file source rather than
    /// checking whether one is already armed: the directory watch and the
    /// old file source's own delete/rename teardown (below) can fire in
    /// either order, and always tearing down + re-opening avoids depending
    /// on that order. `armFileWatch()`'s own cancel handler closes the
    /// previous fd, so repeated re-arming across many renames does not leak
    /// descriptors.
    ///
    /// Tolerates the file not existing: `open()` failing here is normal,
    /// not an error. The directory watch calls this again once something
    /// creates the file.
    private func armFileWatch() {
        fileSource?.cancel()
        fileSource = nil

        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            if event.contains(.delete) || event.contains(.rename) {
                // This fd no longer refers to a live signal file (removed,
                // or replaced by a rename that unlinked it). Tear this
                // watch down; the directory watch's own event for the same
                // change re-arms it. Only clear `fileSource` if it still
                // points at this source - a newer `armFileWatch()` call may
                // have already replaced it by the time this stale event is
                // processed.
                source.cancel()
                if self.fileSource === source {
                    self.fileSource = nil
                }
            }
            if event.contains(.write) || event.contains(.extend) {
                self.scheduleRead()
            }
        }
        // Same discipline as the directory watch's cancel handler: capture
        // `descriptor` by value so each re-arm closes exactly the fd it
        // owns, regardless of how `fileSource` has changed by the time this
        // runs.
        source.setCancelHandler {
            close(descriptor)
        }
        fileSource = source
        source.resume()
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
