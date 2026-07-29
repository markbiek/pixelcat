import Foundation

/// Remembers which animal the user picked.
///
/// Mirrors PositionStore: a persisted value that no longer makes sense is
/// discarded quietly rather than crashing or resurrecting something that is
/// not there. Here that means an animal whose art has since been removed.
enum AnimalStore {
    private static let key = "selectedAnimal"

    static func save(_ name: String) {
        UserDefaults.standard.set(name, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func load(validAnimals: [String]) -> String? {
        guard let name = UserDefaults.standard.string(forKey: key) else { return nil }
        return validAnimals.contains(name) ? name : nil
    }
}
