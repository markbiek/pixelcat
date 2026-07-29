import AppKit
import PixelCatCore

struct LoadedResources {
    let sheet: SpriteSheet
    let image: NSImage
}

enum ResourceError: Error, CustomStringConvertible {
    case missing(String)
    case undecodable(String)
    case invalid(String)

    var description: String {
        switch self {
        case .missing(let name):
            return "\(name) is missing from the app bundle"
        case .undecodable(let name):
            return "\(name) could not be decoded"
        case .invalid(let detail):
            return detail
        }
    }
}

enum Resources {
    /// Reads animals.json and enumerates Resources/animals for available animals.
    static func loadCatalog() throws -> AnimalCatalog {
        guard let url = Bundle.main.url(forResource: "animals", withExtension: "json") else {
            throw ResourceError.missing("animals.json")
        }
        let document = try JSONDecoder().decode(CatalogDocument.self, from: Data(contentsOf: url))

        let manifestURLs = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: "animals"
        ) ?? []
        let discovered = manifestURLs.map { $0.deletingPathExtension().lastPathComponent }

        return try AnimalCatalog(document: document, discovered: discovered)
    }

    /// Loads every discovered animal. Bundled-resource failures are fatal at
    /// launch by design, so validating all animals here means a broken sheet
    /// for a non-default animal surfaces immediately rather than on the click
    /// that first selects it — and makes switching infallible at runtime.
    static func loadAll() throws -> (catalog: AnimalCatalog, animals: [String: LoadedResources]) {
        let catalog = try loadCatalog()
        var animals: [String: LoadedResources] = [:]
        for name in catalog.animalNames {
            animals[name] = try loadAnimal(name, geometry: catalog.geometry)
        }
        return (catalog, animals)
    }

    /// One animal's manifest and sprite sheet, from Resources/animals/<name>.{json,png}.
    static func loadAnimal(_ name: String, geometry: SpriteGeometry) throws -> LoadedResources {
        guard let manifestURL = Bundle.main.url(
            forResource: name, withExtension: "json", subdirectory: "animals"
        ) else {
            throw ResourceError.missing("animals/\(name).json")
        }
        guard let imageURL = Bundle.main.url(
            forResource: name, withExtension: "png", subdirectory: "animals"
        ) else {
            throw ResourceError.missing("animals/\(name).png")
        }

        let manifest: Manifest
        do {
            manifest = try Manifest.decode(from: Data(contentsOf: manifestURL))
        } catch {
            throw ResourceError.invalid("animals/\(name).json: \(error)")
        }

        guard let loaded = NSImage(contentsOf: imageURL),
              let cgImage = loaded.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw ResourceError.undecodable("animals/\(name).png")
        }

        // Rebuild at explicit pixel dimensions. NSImage.size comes from DPI
        // metadata and need not match the pixel grid the manifest describes.
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: pixelSize)

        let sheet: SpriteSheet
        do {
            sheet = try SpriteSheet(geometry: geometry, manifest: manifest, sheetSize: pixelSize)
        } catch {
            throw ResourceError.invalid("animals/\(name).png: \(error)")
        }
        return LoadedResources(sheet: sheet, image: image)
    }
}
