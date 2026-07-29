import Foundation

/// Watches a file for a one-word token drawn from a fixed vocabulary.
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
///
/// `start()` and `stop()` must be called from a single consistent context.
/// `AppDelegate` gets this for free today because its watcher properties are
/// `@MainActor`-isolated, which the compiler enforces for that one consumer -
/// this type itself does nothing to serialize the two against each other.
public final class FileTokenWatcher {
    private let fileURL: URL
    private let directoryURL: URL
    private let validTokens: Set<String>
    private let onToken: @MainActor (String) -> Void
    private let queue: DispatchQueue

    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    /// The inode `armFileWatch()` last opened, or 0 when the file was absent.
    ///
    /// The directory watch fires for *any* entry change in the parent
    /// directory, including changes to files this watcher does not care about.
    /// That is harmless when a directory holds one watched file, but the app
    /// keeps `state` and `animal` side by side, so writing one would otherwise
    /// make the other re-read and re-apply its own stale contents. Comparing
    /// inodes tells a real create/replace/delete of *this* file apart from a
    /// sibling's churn.
    private var watchedInode: ino_t = 0

    public init(
        fileURL: URL,
        validTokens: Set<String>,
        onToken: @escaping @MainActor (String) -> Void
    ) {
        self.fileURL = fileURL
        self.directoryURL = fileURL.deletingLastPathComponent()
        self.validTokens = validTokens
        self.onToken = onToken
        // Named after the watched file so two watchers (state, animal) show
        // up as distinct queues in crash logs and Instruments traces.
        self.queue = DispatchQueue(label: "com.markbiek.pixelcat.signal.\(fileURL.lastPathComponent)")
    }

    /// Interprets the contents of a token file. Returns nil for anything empty
    /// or unrecognized, which callers treat as "leave things alone".
    public static func parse(_ contents: String, validTokens: Set<String>) -> String? {
        let firstLine = contents.split(
            separator: "\n",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).first.map(String.init) ?? ""

        let token = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if token.isEmpty { return nil }
        return validTokens.contains(token) ? token : nil
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
            // A directory entry changed (create, rename-into, or delete).
            // Re-arm the file watch against whatever exists at `fileURL` now.
            // Only treat it as a content change if the file this watcher owns
            // actually came, went, or was replaced - the event may equally
            // have been a sibling file that is none of our business.
            guard let self else { return }
            if self.armFileWatch() {
                self.scheduleRead()
            }
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
            _ = armFileWatch()
        }
    }

    deinit {
        stop()
    }

    public func stop() {
        // `directorySource` must be cancelled first and from inside `queue`,
        // not after it: its event handler is what re-arms `fileSource` and
        // `pending` (via armFileWatch() / scheduleRead()). If it were
        // cancelled outside queue.sync, the serial queue is briefly idle
        // between the sync block returning and this cancel running, and a
        // directory event delivered in that window would call armFileWatch()
        // and resurrect a resumed file source with a pending read - exactly
        // what this function is trying to tear down. Cancelling it first,
        // on the same queue as its own handler, closes that window.
        queue.sync {
            directorySource?.cancel()
            directorySource = nil
            pending?.cancel()
            pending = nil
            fileSource?.cancel()
            fileSource = nil
        }
    }

    /// Arms (or re-arms) a watch on the watched file's own descriptor, so
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
    ///
    /// Returns whether the watched file's identity changed - created, deleted,
    /// or replaced by a different inode. The directory watch uses this to
    /// ignore entry changes that were really about some sibling file.
    /// `start()` discards it: arming a watch is not a content change, which is
    /// what keeps a signal left over from a previous session from being read
    /// at launch.
    private func armFileWatch() -> Bool {
        fileSource?.cancel()
        fileSource = nil

        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // Gone. Report a change only if it was there a moment ago, so a
            // sibling's churn while our file stays absent stays silent.
            defer { watchedInode = 0 }
            return watchedInode != 0
        }

        // fstat on the descriptor just opened rather than stat on the path:
        // the path could be replaced between the two calls, and the inode
        // recorded must be the one this source is about to watch.
        var info = stat()
        let inode = fstat(descriptor, &info) == 0 ? info.st_ino : 0
        let identityChanged = inode != watchedInode
        watchedInode = inode

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
        return identityChanged
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
        guard let token = FileTokenWatcher.parse(contents, validTokens: validTokens) else {
            FileHandle.standardError.write(Data(
                "pixelcat: ignoring unrecognized signal in \(fileURL.path)\n".utf8
            ))
            return
        }
        let callback = onToken
        Task { @MainActor in
            callback(token)
        }
    }
}
