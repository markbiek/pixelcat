import CoreGraphics
import Foundation

/// Maps (state, frame) pairs onto rectangles in the sprite sheet PNG.
///
/// The manifest addresses rows top-down, the way they appear in an image
/// editor. CoreGraphics and NSImage address them bottom-up. The conversion
/// happens here and nowhere else.
public struct SpriteSheet: Sendable {
    public let manifest: Manifest
    public let sheetSize: CGSize

    /// On-screen side length of the cat window, in points.
    public var windowSide: CGFloat {
        CGFloat(manifest.cellSize * manifest.scale)
    }

    public init(manifest: Manifest, sheetSize: CGSize) throws {
        let cell = CGFloat(manifest.cellSize)
        for name in manifest.orderedStateNames {
            let state = manifest.states[name]!
            let neededWidth = CGFloat(state.frames) * cell
            guard neededWidth <= sheetSize.width else {
                throw SpriteSheetError.sheetTooSmall(
                    state: name,
                    needed: "width \(neededWidth)",
                    actual: "width \(sheetSize.width)"
                )
            }
            let neededHeight = CGFloat(state.row + 1) * cell
            guard neededHeight <= sheetSize.height else {
                throw SpriteSheetError.sheetTooSmall(
                    state: name,
                    needed: "height \(neededHeight)",
                    actual: "height \(sheetSize.height)"
                )
            }
        }
        self.manifest = manifest
        self.sheetSize = sheetSize
    }

    public func frameRect(state name: String, frame: Int) throws -> CGRect {
        guard let state = manifest.states[name] else {
            throw SpriteSheetError.unknownState(name)
        }
        let cell = CGFloat(manifest.cellSize)
        let column = ((frame % state.frames) + state.frames) % state.frames
        return CGRect(
            x: CGFloat(column) * cell,
            y: sheetSize.height - CGFloat(state.row + 1) * cell,
            width: cell,
            height: cell
        )
    }
}

public enum SpriteSheetError: Error, Equatable, CustomStringConvertible {
    case unknownState(String)
    case sheetTooSmall(state: String, needed: String, actual: String)

    public var description: String {
        switch self {
        case .unknownState(let name):
            return "no state named '\(name)' in states.json"
        case .sheetTooSmall(let state, let needed, let actual):
            return "cat.png is too small for state '\(state)': needs \(needed), has \(actual)"
        }
    }
}
