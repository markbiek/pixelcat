import Foundation

/// Sprite dimensions shared by every animal.
///
/// Hoisted out of the per-animal manifest deliberately: repeating these values
/// per animal and validating they agree would make a mismatch detectable, while
/// defining them once makes it unrepresentable. That is what guarantees the
/// floating window never has to resize when the animal changes.
public struct SpriteGeometry: Codable, Equatable, Sendable {
    public let cellSize: Int
    public let scale: Int

    public init(cellSize: Int, scale: Int) {
        self.cellSize = cellSize
        self.scale = scale
    }

    public func validate() throws {
        guard cellSize > 0 else {
            throw GeometryError.invalid("cellSize must be positive, got \(cellSize)")
        }
        guard scale >= 1 else {
            throw GeometryError.invalid("scale must be at least 1, got \(scale)")
        }
    }
}

public enum GeometryError: Error, Equatable, CustomStringConvertible {
    case invalid(String)

    public var description: String {
        switch self {
        case .invalid(let detail):
            return "animals.json geometry is invalid: \(detail)"
        }
    }
}
