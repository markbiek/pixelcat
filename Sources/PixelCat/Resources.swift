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
    static func load() throws -> LoadedResources {
        guard let manifestURL = Bundle.main.url(forResource: "states", withExtension: "json") else {
            throw ResourceError.missing("states.json")
        }
        guard let imageURL = Bundle.main.url(forResource: "cat", withExtension: "png") else {
            throw ResourceError.missing("cat.png")
        }

        let manifest = try Manifest.decode(from: Data(contentsOf: manifestURL))

        guard let loaded = NSImage(contentsOf: imageURL),
              let cgImage = loaded.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw ResourceError.undecodable("cat.png")
        }

        // Rebuild at explicit pixel dimensions. NSImage.size comes from DPI
        // metadata and need not match the pixel grid the manifest describes.
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: pixelSize)

        let sheet = try SpriteSheet(manifest: manifest, sheetSize: pixelSize)
        return LoadedResources(sheet: sheet, image: image)
    }
}
