import AppKit
import PixelCatCore

/// Everything speech: the bubble, the phrase pool, the say/learn files,
/// idle chatter, and overnight learning. AppDelegate only constructs it,
/// starts/stops it, and reports state changes.
@MainActor
final class SpeechController {
    /// How often the animal chats unprompted, jittered so it isn't a
    /// metronome. Also the polling cadence for the overnight check, which
    /// is why "first timer tick after 4 AM" lands within ~20 minutes.
    static let chatterInterval: ClosedRange<Double> = 600...1200

    /// Chance of a remark when the animal changes state on its own.
    static let transitionChatterChance = 0.25

    private let store: PhraseStore
    private let sayURL: URL
    private let learnURL: URL
    private let bubble = SpeechBubbleWindow()
    private unowned let catWindow: NSWindow
    private let currentState: () -> String

    private var sayWatcher: FileTokenWatcher?
    private var learnWatcher: FileTokenWatcher?
    private var chatterTimer: Timer?
    private var dismissTimer: Timer?
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

    /// One-shot: speak the first line, remember nothing, consume the file.
    private func handleSay(_ contents: String) {
        let firstLine = contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first.map(String.init) ?? ""
        let text = firstLine.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            speak(String(text.prefix(Phrase.maxLength)))
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

    private func speak(_ text: String) {
        bubble.show(text: text, above: catWindow)
        scheduleDismissTimer(for: text)
    }

    private func speakFromPool() {
        let phrase = PhraseBook.pick(
            from: store.loadPool(),
            state: currentState(),
            roll: Double.random(in: 0..<1, using: &rng)
        )
        if let phrase {
            speak(phrase.text)
        }
    }

    private func scheduleDismissTimer(for text: String) {
        dismissTimer?.invalidate()
        let duration = min(3.0 + 0.05 * Double(text.count), 8.0)
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
        guard !learned.isEmpty else { return false }
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
