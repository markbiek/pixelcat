import Foundation

/// One animation state: which row of the sprite sheet it occupies, how many
/// frames it has, how fast it plays, and how likely the cat is to choose it.
public struct StateDefinition: Codable, Equatable, Sendable {
    public let row: Int
    public let frames: Int
    public let fps: Double
    public let weight: Double

    public init(row: Int, frames: Int, fps: Double, weight: Double) {
        self.row = row
        self.frames = frames
        self.fps = fps
        self.weight = weight
    }
}

public struct Manifest: Codable, Equatable, Sendable {
    public let cellSize: Int
    public let scale: Int
    public let defaultState: String
    public let decideIntervalSeconds: [Double]
    public let states: [String: StateDefinition]

    public var decideInterval: ClosedRange<Double> {
        decideIntervalSeconds[0]...decideIntervalSeconds[1]
    }

    /// Names in a stable order. Dictionary iteration order is not guaranteed
    /// in Swift, and both weighted selection and the status menu need to be
    /// reproducible run to run.
    public var orderedStateNames: [String] {
        states.keys.sorted()
    }

    public static func decode(from data: Data) throws -> Manifest {
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        try manifest.validate()
        return manifest
    }

    public func validate() throws {
        guard cellSize > 0 else {
            throw ManifestError.invalidGeometry("cellSize must be positive, got \(cellSize)")
        }
        guard scale >= 1 else {
            throw ManifestError.invalidGeometry("scale must be at least 1, got \(scale)")
        }
        guard !states.isEmpty else {
            throw ManifestError.emptyStates
        }
        guard states[defaultState] != nil else {
            throw ManifestError.unknownDefaultState(defaultState)
        }
        guard decideIntervalSeconds.count == 2 else {
            throw ManifestError.invalidInterval("expected exactly 2 values, got \(decideIntervalSeconds.count)")
        }
        let lower = decideIntervalSeconds[0]
        let upper = decideIntervalSeconds[1]
        guard lower > 0, upper >= lower else {
            throw ManifestError.invalidInterval("expected 0 < min <= max, got \(lower) and \(upper)")
        }
        for name in orderedStateNames {
            let state = states[name]!
            guard state.row >= 0 else {
                throw ManifestError.invalidState(name: name, reason: "row must not be negative")
            }
            guard state.frames >= 1 else {
                throw ManifestError.invalidState(name: name, reason: "frames must be at least 1")
            }
            guard state.fps > 0 else {
                throw ManifestError.invalidState(name: name, reason: "fps must be positive")
            }
            guard state.weight > 0 else {
                throw ManifestError.invalidState(name: name, reason: "weight must be positive")
            }
        }
    }
}

public enum ManifestError: Error, Equatable, CustomStringConvertible {
    case emptyStates
    case unknownDefaultState(String)
    case invalidGeometry(String)
    case invalidInterval(String)
    case invalidState(name: String, reason: String)

    public var description: String {
        switch self {
        case .emptyStates:
            return "states.json declares no states"
        case .unknownDefaultState(let name):
            return "states.json defaultState '\(name)' is not one of the declared states"
        case .invalidGeometry(let detail):
            return "states.json geometry is invalid: \(detail)"
        case .invalidInterval(let detail):
            return "states.json decideIntervalSeconds is invalid: \(detail)"
        case .invalidState(let name, let reason):
            return "states.json state '\(name)' is invalid: \(reason)"
        }
    }
}
