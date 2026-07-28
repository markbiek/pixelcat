import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate

// No Dock icon, no app menu. Info.plist sets LSUIElement for the bundle;
// this covers running the bare binary during development.
application.setActivationPolicy(.accessory)
application.run()
