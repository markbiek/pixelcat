import AppKit
import PixelCatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var resources: LoadedResources!
    private var catalog: AnimalCatalog!
    private var animals: [String: LoadedResources] = [:]
    private var currentAnimal: String!
    private var brain: CatBrain!
    private var window: CatWindow!
    private var catView: CatView!

    private var frameTimer: Timer?
    private var decideTimer: Timer?
    private var rng = SystemRandomNumberGenerator()
    private var statusItemController: StatusItemController!
    private var signalWatcher: StateSignalWatcher?
    private var animalWatcher: FileTokenWatcher?
    private var speechController: SpeechController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let loaded = try Resources.loadAll()
            catalog = loaded.catalog
            animals = loaded.animals
            currentAnimal = AnimalStore.load(validAnimals: catalog.animalNames)
                ?? catalog.defaultAnimal
            resources = animals[currentAnimal]!
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

        speechController = SpeechController(
            directory: StateSignal.defaultFileURL.deletingLastPathComponent(),
            catWindow: window,
            currentState: { [weak self] in self?.brain.state ?? "" }
        )
        speechController.start()

        statusItemController = StatusItemController(
            animalNames: catalog.animalNames,
            stateNames: resources.sheet.manifest.orderedStateNames,
            onSelectAnimal: { [weak self] name in
                self?.switchTo(animal: name)
            },
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
            currentAnimal: currentAnimal,
            currentState: brain.state,
            isAutonomous: brain.isAutonomous
        )

        scheduleFrameTimer()
        scheduleDecideTimer()

        restartSignalWatcher()
        startAnimalWatcher()
    }

    func applicationWillTerminate(_ notification: Notification) {
        frameTimer?.invalidate()
        decideTimer?.invalidate()
        signalWatcher?.stop()
        animalWatcher?.stop()
        speechController?.stop()
    }

    /// Started once and never rebuilt, unlike the state watcher: the set of
    /// animals is fixed at launch, so this watcher's vocabulary never goes
    /// stale the way a per-animal state vocabulary does.
    private func startAnimalWatcher() {
        let animalFile = StateSignal.defaultFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("animal", isDirectory: false)
        let watcher = FileTokenWatcher(
            fileURL: animalFile,
            validTokens: Set(catalog.animalNames)
        ) { [weak self] name in
            self?.switchTo(animal: name)
        }
        do {
            try watcher.start()
            animalWatcher = watcher
        } catch {
            FileHandle.standardError.write(Data("pixelcat: \(error)\n".utf8))
        }
    }

    /// The watcher is constructed with a fixed set of valid state names, so it
    /// must be rebuilt when the animal's vocabulary changes.
    private func restartSignalWatcher() {
        signalWatcher?.stop()
        signalWatcher = nil

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
        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(frameTimerFired),
            userInfo: nil,
            repeats: false
        )
        // .common rather than scheduledTimer's default-only mode: window
        // dragging and NSMenu tracking both run the run loop in
        // NSEventTrackingRunLoopMode, and a default-mode timer does not fire
        // there, so the cat would freeze mid-drag and while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
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
        let timer = Timer(
            timeInterval: delay,
            target: self,
            selector: #selector(decideTimerFired),
            userInfo: nil,
            repeats: false
        )
        // Same .common reasoning as scheduleFrameTimer(): without it, a long
        // drag or menu-open silently postpones the next mood change.
        RunLoop.main.add(timer, forMode: .common)
        decideTimer = timer
    }

    @objc
    private func decideTimerFired() {
        let before = brain.state
        brain.decide(using: &rng)
        if brain.state != before {
            scheduleFrameTimer()
            redraw()
            statusItemController.refresh(
                currentAnimal: currentAnimal,
                currentState: brain.state,
                isAutonomous: brain.isAutonomous
            )
            speechController.noteStateChanged()
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
            currentAnimal: currentAnimal,
            currentState: brain.state,
            isAutonomous: brain.isAutonomous
        )
    }

    /// Changes which animal is on screen.
    ///
    /// Every animal was loaded and validated at launch, so this cannot fail.
    /// A pinned state deliberately does not survive the switch: state
    /// vocabularies differ between animals, and "your pin sometimes survives"
    /// is worse to use than "switching always starts fresh".
    func switchTo(animal name: String) {
        guard name != currentAnimal, let loaded = animals[name] else { return }

        // Shared geometry makes this true by construction. The check exists so
        // that reintroducing per-animal geometry fails loudly here rather than
        // silently clipping the sprite against a stale window size.
        precondition(
            loaded.sheet.windowSide == resources.sheet.windowSide,
            "animal '\(name)' has a different window size; geometry must be shared"
        )

        resources = loaded
        currentAnimal = name
        brain = CatBrain(manifest: loaded.sheet.manifest)
        AnimalStore.save(name)

        restartSignalWatcher()
        scheduleFrameTimer()
        scheduleDecideTimer()
        redraw()

        statusItemController.setStates(loaded.sheet.manifest.orderedStateNames)
        statusItemController.refresh(
            currentAnimal: currentAnimal,
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
