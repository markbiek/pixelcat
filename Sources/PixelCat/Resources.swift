import AppKit
import PixelCatCore

struct LoadedResources {
    let sheet: SpriteSheet
    let image: NSImage
}

enum ResourceError: Error, CustomStringConvertible {
    case missing(String)
    case undecodable(String)

    var description: String {
        switch self {
        case .missing(let name):
            return "\(name) is missing from the app bundle"
        case .undecodable(let name):
            return "\(name) could not be decoded"
        }
    }
}

enum Resources {
    /// Shared sprite geometry, read from animals.json.
    static func loadGeometry() throws -> SpriteGeometry {
        guard let url = Bundle.main.url(forResource: "animals", withExtension: "json") else {
            throw ResourceError.missing("animals.json")
        }
        let geometry = try JSONDecoder().decode(SpriteGeometry.self, from: Data(contentsOf: url))
        try geometry.validate()
        return geometry
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

        let manifest = try Manifest.decode(from: Data(contentsOf: manifestURL))

        guard let loaded = NSImage(contentsOf: imageURL),
              let cgImage = loaded.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw ResourceError.undecodable("animals/\(name).png")
        }

        // Rebuild at explicit pixel dimensions. NSImage.size comes from DPI
        // metadata and need not match the pixel grid the manifest describes.
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: pixelSize)

        let sheet = try SpriteSheet(geometry: geometry, manifest: manifest, sheetSize: pixelSize)
        return LoadedResources(sheet: sheet, image: image)
    }
}
