import Foundation

/// The on-disk shape of animals.json. Flat rather than nested so the file stays
/// pleasant to hand-edit; `geometry` reassembles the two dimension fields.
public struct CatalogDocument: Codable, Equatable, Sendable {
    public let cellSize: Int
    public let scale: Int
    public let defaultAnimal: String

    public init(cellSize: Int, scale: Int, defaultAnimal: String) {
        self.cellSize = cellSize
        self.scale = scale
        self.defaultAnimal = defaultAnimal
    }

    public var geometry: SpriteGeometry {
        SpriteGeometry(cellSize: cellSize, scale: scale)
    }
}

/// The set of animals the app can show, plus the geometry they all share.
///
/// Names arrive from bundle enumeration rather than a hardcoded list, so
/// dropping a new PNG and JSON into Resources/animals adds an animal with no
/// code change. Enumeration order is not stable, so names are sorted here for
/// the same reason `Manifest.orderedStateNames` sorts: the menu must not
/// reshuffle between launches.
public struct AnimalCatalog: Equatable, Sendable {
    public let geometry: SpriteGeometry
    public let defaultAnimal: String
    public let animalNames: [String]

    public init(document: CatalogDocument, discovered: [String]) throws {
        try document.geometry.validate()

        let names = Array(Set(discovered)).sorted()
        guard !names.isEmpty else {
            throw AnimalCatalogError.noAnimals
        }
        guard names.contains(document.defaultAnimal) else {
            throw AnimalCatalogError.unknownDefaultAnimal(
                name: document.defaultAnimal,
                available: names
            )
        }

        self.geometry = document.geometry
        self.defaultAnimal = document.defaultAnimal
        self.animalNames = names
    }
}

public enum AnimalCatalogError: Error, Equatable, CustomStringConvertible {
    case noAnimals
    case unknownDefaultAnimal(name: String, available: [String])

    public var description: String {
        switch self {
        case .noAnimals:
            return "no animals found in Resources/animals"
        case .unknownDefaultAnimal(let name, let available):
            return "animals.json defaultAnimal '\(name)' was not found; available: \(available.joined(separator: ", "))"
        }
    }
}
