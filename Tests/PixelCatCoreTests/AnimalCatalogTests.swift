import Testing
import Foundation
@testable import PixelCatCore

private let catalogJSON = #"""
{ "cellSize": 24, "scale": 3, "defaultAnimal": "cat" }
"""#

private func makeDocument() throws -> CatalogDocument {
    try JSONDecoder().decode(CatalogDocument.self, from: Data(catalogJSON.utf8))
}

@Test func decodesTheCatalogDocument() throws {
    let document = try makeDocument()
    #expect(document.defaultAnimal == "cat")
    #expect(document.geometry == SpriteGeometry(cellSize: 24, scale: 3))
}

@Test func sortsDiscoveredAnimalNames() throws {
    let catalog = try AnimalCatalog(document: makeDocument(), discovered: ["dog", "cat", "bat"])
    #expect(catalog.animalNames == ["bat", "cat", "dog"])
}

@Test func rejectsAnEmptyAnimalSet() throws {
    let document = try makeDocument()
    #expect(throws: AnimalCatalogError.noAnimals) {
        try AnimalCatalog(document: document, discovered: [])
    }
}

@Test func rejectsADefaultAnimalThatWasNotDiscovered() throws {
    let document = try makeDocument()
    #expect(throws: AnimalCatalogError.unknownDefaultAnimal(name: "cat", available: ["bat", "dog"])) {
        try AnimalCatalog(document: document, discovered: ["dog", "bat"])
    }
}

@Test func rejectsInvalidGeometry() throws {
    let json = #"{ "cellSize": 0, "scale": 3, "defaultAnimal": "cat" }"#
    let document = try JSONDecoder().decode(CatalogDocument.self, from: Data(json.utf8))
    #expect(throws: GeometryError.self) {
        try AnimalCatalog(document: document, discovered: ["cat"])
    }
}

@Test func deduplicatesDiscoveredNames() throws {
    // Bundle enumeration can legitimately surface the same name twice if a
    // resource is listed under more than one path; the catalog must not put
    // two identical entries in the menu.
    let catalog = try AnimalCatalog(document: makeDocument(), discovered: ["cat", "cat", "dog"])
    #expect(catalog.animalNames == ["cat", "dog"])
}
