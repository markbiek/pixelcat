import AppKit
import PixelCatCore

/// Everything speech: the bubble, the phrase pool, the say/learn files,
/// idle chatter, and overnight learning. AppDelegate only constructs it,
/// starts/stops it, and reports state changes.
@MainActor
final class SpeechController {
    /// How often the animal chats unprompted, jittered so it isn't a
    /// metronome. Also the polling cadence for the overnight check, which
    /// is why "first timer tick after 4 AM" lands within ~10 minutes.
    static let chatterInterval: ClosedRange<Double> = 300...600

    /// Chance of a remark when the animal changes state on its own.
    static let transitionChatterChance = 0.25

    /// States where a say message is an interruption: the animal protests
    /// with a quick shake before delivering it. Matched by name, so the
    /// bat's `hang` deliberately doesn't count as dozing.
    static let disturbedStates: Set<String> = ["idle", "sleep"]

    private let store: PhraseStore
    private let sayURL: URL
    private let learnURL: URL
    private let bubble = SpeechBubbleWindow()
    // Safe unowned: AppDelegate creates this window once and never reassigns
    // it (switchTo(animal:) reuses the same window), so it outlives us.
    private unowned let catWindow: NSWindow
    private let currentState: () -> String

    private var sayWatcher: FileTokenWatcher?
    private var learnWatcher: FileTokenWatcher?
    private var chatterTimer: Timer?
    private var dismissTimer: Timer?
    private var shakeTimer: Timer?
    private var shakeStep = 0
    private var shakeOrigin = NSPoint.zero
    private var pendingShakeText: String?
    private var pendingShakeOnClick: (() -> Void)?
    private var rng = SystemRandomNumberGenerator()

    init(directory: URL, catWindow: NSWindow, currentState: @escaping () -> String) {
        self.store = PhraseStore(directory: directory)
        self.sayURL = directory.appendingPathComponent("say", isDirectory: false)
        self.learnURL = directory.appendingPathComponent("learn", isDirectory: false)
        self.catWindow = catWindow
        self.currentState = currentState
    }

    func start() {
        do {
            try store.seedPoolIfMissing(PhraseStore.starterPhrases)
        } catch {
            warn("cannot seed phrases: \(error)")
        }
        startWatchers()
        // At-launch check: a morning login counts as the first tick after 4 AM.
        activateOvernightLearningIfDue()
        scheduleChatterTimer()
    }

    func stop() {
        sayWatcher?.stop()
        learnWatcher?.stop()
        chatterTimer?.invalidate()
        dismissTimer?.invalidate()
        shakeTimer?.invalidate()
    }

    /// Called on autonomous state changes; sometimes the animal remarks on
    /// its new mood.
    func noteStateChanged() {
        guard Double.random(in: 0..<1, using: &rng) < Self.transitionChatterChance else {
            return
        }
        speakFromPool()
    }

    // MARK: - Watchers

    private func startWatchers() {
        let say = FileTokenWatcher(fileURL: sayURL) { [weak self] contents in
            self?.handleSay(contents)
        }
        let learn = FileTokenWatcher(fileURL: learnURL) { [weak self] contents in
            self?.handleLearn(contents)
        }
        do {
            try say.start()
            sayWatcher = say
            try learn.start()
            learnWatcher = learn
        } catch {
            // A cat that cannot be scripted is still a cat.
            warn("\(error)")
        }
    }

    /// One-shot: speak it, remember nothing, consume the file. An optional
    /// second line is a shell command run if the bubble is clicked — the
    /// sender's way of saying "click to see what needs attention".
    private func handleSay(_ contents: String) {
        if let message = SayMessage.parse(contents) {
            let onClick = message.clickCommand.map { command in
                { [weak self] in
                    guard let self else { return }
                    self.runClickCommand(command)
                }
            }
            if Self.disturbedStates.contains(currentState()) {
                shakeThenSpeak(message.text, onClick: onClick)
            } else {
                speak(message.text, onClick: onClick)
            }
        }
        consume(sayURL)
    }

    /// Every line is a phrase headed for the backlog; the cat learns them
    /// overnight. Consume the file so re-writes never double-teach.
    private func handleLearn(_ contents: String) {
        let phrases = PhraseBook.parse(contents)
        do {
            try store.appendToBacklog(phrases)
        } catch {
            warn("cannot write backlog: \(error)")
            return // leave the learn file in place so nothing is lost
        }
        consume(learnURL)
    }

    private func consume(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Speaking

    private func speak(_ text: String, onClick: (() -> Void)? = nil) {
        bubble.show(text: text, above: catWindow, onClick: onClick)
        scheduleDismissTimer(for: text, clickable: onClick != nil)
    }

    /// A login shell so the command sees the user's PATH — the app itself
    /// launches from Finder with the bare system one.
    private func runClickCommand(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        do {
            try process.run()
        } catch {
            warn("cannot run click command: \(error)")
        }
    }

    /// The cat's own remarks are the lowest-priority speech: never replace
    /// a bubble someone might still be reading — or about to click.
    private func speakFromPool() {
        guard !bubble.isShowingBubble else { return }
        let phrase = PhraseBook.pick(
            from: store.loadPool(),
            state: currentState(),
            roll: Double.random(in: 0..<1, using: &rng)
        )
        if let phrase {
            speak(phrase.text)
        }
    }

    /// Clickable bubbles are invitations, so they linger longer than the
    /// cat's own passing remarks.
    private func scheduleDismissTimer(for text: String, clickable: Bool) {
        dismissTimer?.invalidate()
        let base = clickable ? 12.0 : 4.5
        let cap = clickable ? 20.0 : 10.0
        let duration = min(base + 0.05 * Double(text.count), cap)
        let timer = Timer(
            timeInterval: duration,
            target: self,
            selector: #selector(dismissTimerFired),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(timer, forMode: .common)
        dismissTimer = timer
    }

    @objc
    private func dismissTimerFired() {
        bubble.hide()
    }

    // MARK: - Grumpy shake

    /// Roughly half a second at 60 Hz — long enough to read as a
    /// protest, short enough not to delay a notification meaningfully.
    private static let shakeSteps = 30
    private static let shakeAmplitude: CGFloat = 5

    /// A decaying horizontal jiggle of the cat window, then the message.
    /// Timers here follow the same target/selector + .common discipline as
    /// everything else, so the shake doesn't freeze mid-drag or mid-menu.
    private func shakeThenSpeak(_ text: String, onClick: (() -> Void)? = nil) {
        pendingShakeText = text
        pendingShakeOnClick = onClick
        // A say arriving mid-shake must not capture the jiggled position as
        // the origin to restore, so only record it when no shake is running.
        if shakeTimer == nil {
            shakeOrigin = catWindow.frame.origin
            shakeStep = 0
        }
        shakeTimer?.invalidate()
        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(shakeTimerFired),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        shakeTimer = timer
    }

    @objc
    private func shakeTimerFired() {
        shakeStep += 1
        guard shakeStep < Self.shakeSteps else {
            shakeTimer?.invalidate()
            shakeTimer = nil
            catWindow.setFrameOrigin(shakeOrigin)
            if let text = pendingShakeText {
                let onClick = pendingShakeOnClick
                pendingShakeText = nil
                pendingShakeOnClick = nil
                speak(text, onClick: onClick)
            }
            return
        }
        let progress = Double(shakeStep) / Double(Self.shakeSteps)
        let offset = sin(progress * .pi * 8)          // four oscillations
            * Double(Self.shakeAmplitude)
            * (1.0 - progress)                        // dying down, not a buzz
        catWindow.setFrameOrigin(NSPoint(x: shakeOrigin.x + offset, y: shakeOrigin.y))
    }

    // MARK: - Chatter and overnight learning

    private func scheduleChatterTimer() {
        chatterTimer?.invalidate()
        let delay = Double.random(in: Self.chatterInterval, using: &rng)
        let timer = Timer(
            timeInterval: delay,
            target: self,
            selector: #selector(chatterTimerFired),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(timer, forMode: .common)
        chatterTimer = timer
    }

    @objc
    private func chatterTimerFired() {
        // The announcement is its own moment: when learning fires, skip the
        // regular chatter this tick.
        if !activateOvernightLearningIfDue() {
            speakFromPool()
        }
        scheduleChatterTimer()
    }

    /// Drains the backlog when the 4 AM window has passed. Returns whether
    /// an announcement was made.
    @discardableResult
    private func activateOvernightLearningIfDue() -> Bool {
        guard OvernightLearning.shouldActivate(
            now: Date(),
            lastActivation: LearningStore.loadLastActivation()
        ) else {
            return false
        }
        let learned: [Phrase]
        do {
            learned = try store.drainBacklog()
        } catch {
            warn("cannot drain backlog: \(error)")
            return false
        }
        // Record even an empty drain: the window was consumed, and there is
        // no need to re-stat the backlog until tomorrow.
        LearningStore.saveLastActivation(Date())
        // The phrases are learned either way; the announcement is skippable
        // whimsy and must not clobber a bubble already on screen.
        guard !learned.isEmpty, !bubble.isShowingBubble else { return false }
        speak(learned.count == 1
            ? "I learned a new thing!"
            : "I learned \(learned.count) new things!")
        return true
    }

    private func warn(_ message: String) {
        FileHandle.standardError.write(Data("pixelcat: \(message)\n".utf8))
    }
}

/// Remembers when the backlog last drained. Mirrors AnimalStore: a plain
/// UserDefaults value, absent on first run.
private enum LearningStore {
    private static let key = "lastLearnActivation"

    static func saveLastActivation(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    static func loadLastActivation() -> Date? {
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: key))
    }
}
