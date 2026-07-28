import AppKit

/// Remembers where the cat was left, and refuses to restore it somewhere the
/// user cannot see — a monitor that is no longer attached, most often.
enum PositionStore {
    private static let xKey = "catOriginX"
    private static let yKey = "catOriginY"

    static func save(_ origin: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(Double(origin.x), forKey: xKey)
        defaults.set(Double(origin.y), forKey: yKey)
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: xKey)
        defaults.removeObject(forKey: yKey)
    }

    static func load(side: CGFloat) -> NSPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: xKey) != nil,
              defaults.object(forKey: yKey) != nil
        else {
            return nil
        }

        let origin = NSPoint(
            x: defaults.double(forKey: xKey),
            y: defaults.double(forKey: yKey)
        )
        let rect = NSRect(x: origin.x, y: origin.y, width: side, height: side)
        let onSomeScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
        return onSomeScreen ? origin : nil
    }
}
