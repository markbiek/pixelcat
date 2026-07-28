import AppKit
import PixelCatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var resources: LoadedResources!
    private var brain: CatBrain!
    private var window: CatWindow!
    private var catView: CatView!

    private var frameTimer: Timer?
    private var decideTimer: Timer?
    private var rng = SystemRandomNumberGenerator()
    private var statusItemController: StatusItemController!
    private var signalWatcher: StateSignalWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            resources = try Resources.load()
        } catch {
            fail("\(error)")
        }

        brain = CatBrain(manifest: resources.sheet.manifest)

        let side = resources.sheet.windowSide
        window = CatWindow(side: side)
        catView = CatView(
            image: resources.image,
            sourceRect: currentSourceRect(),
            side: side
        )
        window.contentView = catView
        window.setFrameOrigin(
            PositionStore.load(side: side) ?? CatWindow.defaultOrigin(side: side)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
        window.orderFrontRegardless()

        statusItemController = StatusItemController(
            stateNames: resources.sheet.manifest.orderedStateNames,
            onSelectState: { [weak self] name in
                self?.apply(.state(name))
            },
            onResumeAutonomy: { [weak self] in
                self?.apply(.auto)
            },
            onResetPosition: { [weak self] in
                guard let self else { return }
                // Order matters: setFrameOrigin fires windowDidMove
                // synchronously, which would re-save the default origin and
                // undo a clear() called beforehand. Clear last so it wins.
                self.window.setFrameOrigin(
                    CatWindow.defaultOrigin(side: self.resources.sheet.windowSide)
                )
                PositionStore.clear()
            }
        )
        statusItemController.refresh(
            currentState: brain.state,
            isAutonomous: brain.isAutonomous
        )

        scheduleFrameTimer()
        scheduleDecideTimer()

        let watcher = StateSignalWatcher(
            validStates: Set(resources.sheet.manifest.orderedStateNames)
        ) { [weak self] request in
            self?.apply(request)
        }
        do {
            try watcher.start()
            signalWatcher = watcher
        } catch {
            // A cat that cannot be scripted is still a cat. Report and carry on.
            FileHandle.standardError.write(Data("pixelcat: \(error)\n".utf8))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        frameTimer?.invalidate()
        decideTimer?.invalidate()
        signalWatcher?.stop()
    }

    // MARK: - Timers

    /// Rescheduled after every frame because fps varies by state.
    ///
    /// Uses the target/selector API rather than the closure-based one: the
    /// closure overload requires a @Sendable block, and AppDelegate is a
    /// non-Sendable, main-actor-isolated class. Target/selector has no
    /// closure and sidesteps that entirely.
    private func scheduleFrameTimer() {
        frameTimer?.invalidate()
        let interval = 1.0 / brain.currentFPS
        frameTimer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(frameTimerFired),
            userInfo: nil,
            repeats: false
        )
    }

    @objc
    private func frameTimerFired() {
        brain.advanceFrame()
        redraw()
        scheduleFrameTimer()
    }

    /// Rescheduled after every decision at a fresh random interval, so the cat
    /// does not change state on a metronome.
    private func scheduleDecideTimer() {
        decideTimer?.invalidate()
        let delay = brain.nextDecisionDelay(using: &rng)
        decideTimer = Timer.scheduledTimer(
            timeInterval: delay,
            target: self,
            selector: #selector(decideTimerFired),
            userInfo: nil,
            repeats: false
        )
    }

    @objc
    private func decideTimerFired() {
        let before = brain.state
        brain.decide(using: &rng)
        if brain.state != before {
            scheduleFrameTimer()
            redraw()
            statusItemController.refresh(
                currentState: brain.state,
                isAutonomous: brain.isAutonomous
            )
        }
        scheduleDecideTimer()
    }

    // MARK: - Requests

    @objc private func windowDidMove() {
        PositionStore.save(window.frame.origin)
    }

    /// The one place state changes enter the app, whatever their source.
    func apply(_ request: StateRequest) {
        switch request {
        case .state(let name):
            guard brain.requestState(name) else { return }
            decideTimer?.invalidate()
            scheduleFrameTimer()
        case .auto:
            brain.resumeAutonomy()
            scheduleDecideTimer()
        }
        redraw()
        statusItemController.refresh(
            currentState: brain.state,
            isAutonomous: brain.isAutonomous
        )
    }

    // MARK: - Drawing

    private func currentSourceRect() -> CGRect {
        // The brain only ever holds names the manifest declares, so this
        // cannot fail once resources have loaded.
        try! resources.sheet.frameRect(state: brain.state, frame: brain.frame)
    }

    private func redraw() {
        catView.update(image: resources.image, sourceRect: currentSourceRect())
    }

    private func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("pixelcat: \(message)\n".utf8))
        exit(1)
    }
}
