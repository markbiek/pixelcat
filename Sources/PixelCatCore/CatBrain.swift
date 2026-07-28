import Foundation

/// The cat's current state, current frame, and the rules for changing them.
///
/// Deliberately timer-free: the AppKit shell schedules `advanceFrame()` using
/// `currentFPS` and `decide(using:)` using `nextDecisionDelay(using:)`. That
/// keeps every rule in here directly testable.
public struct CatBrain {
    public let manifest: Manifest
    public private(set) var state: String
    public private(set) var frame: Int

    /// While true the cat picks its own states. Any explicit request — from the
    /// menu or the signal file — turns this off, so a deliberate `dance` is not
    /// overwritten by the decide timer seconds later.
    public private(set) var isAutonomous: Bool

    /// Cumulative weight buckets in sorted-name order, normalized to 0...1.
    /// Precomputed because dictionary order is not stable across runs and
    /// selection must be reproducible.
    private let buckets: [(name: String, upperBound: Double)]

    public init(manifest: Manifest) {
        self.manifest = manifest
        self.state = manifest.defaultState
        self.frame = 0
        self.isAutonomous = true

        let names = manifest.orderedStateNames
        let total = names.reduce(0.0) { $0 + manifest.states[$1]!.weight }
        var running = 0.0
        self.buckets = names.map { name in
            running += manifest.states[name]!.weight
            return (name, running / total)
        }
    }

    public var currentFPS: Double {
        manifest.states[state]!.fps
    }

    public var frameCount: Int {
        manifest.states[state]!.frames
    }

    public mutating func advanceFrame() {
        frame = (frame + 1) % frameCount
    }

    /// Pins the cat to a state and stops autonomous behavior.
    /// Returns false, changing nothing, if the name is not in the manifest.
    @discardableResult
    public mutating func requestState(_ name: String) -> Bool {
        guard manifest.states[name] != nil else { return false }
        setState(name)
        isAutonomous = false
        return true
    }

    public mutating func resumeAutonomy() {
        isAutonomous = true
    }

    /// Picks the next state from a value in 0..<1. No-op unless autonomous.
    public mutating func decide(roll: Double) {
        guard isAutonomous else { return }
        let clamped = min(max(roll, 0), 0.999999)
        for bucket in buckets where clamped < bucket.upperBound {
            setState(bucket.name)
            return
        }
        // Unreachable in practice: `running` accumulates the same addends in
        // the same order `total` reduces over, so the last bucket's
        // `running / total` is exactly 1.0 and `clamped` never reaches it.
        // Kept as a defensive fallback rather than force-unwrapping the loop.
        setState(buckets[buckets.count - 1].name)
    }

    public mutating func decide<G: RandomNumberGenerator>(using rng: inout G) {
        decide(roll: Double.random(in: 0..<1, using: &rng))
    }

    public func nextDecisionDelay<G: RandomNumberGenerator>(using rng: inout G) -> Double {
        Double.random(in: manifest.decideInterval, using: &rng)
    }

    /// Re-picking the current state is normal and reads as the cat carrying on,
    /// so the frame is only reset on an actual change.
    private mutating func setState(_ name: String) {
        guard name != state else { return }
        state = name
        frame = 0
    }
}
