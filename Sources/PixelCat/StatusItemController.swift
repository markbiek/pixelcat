import AppKit

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let stateNames: [String]
    private let onSelectState: (String) -> Void
    private let onResumeAutonomy: () -> Void
    private let onResetPosition: () -> Void

    private var stateItems: [String: NSMenuItem] = [:]
    private var autonomyItem: NSMenuItem!

    init(
        stateNames: [String],
        onSelectState: @escaping (String) -> Void,
        onResumeAutonomy: @escaping () -> Void,
        onResetPosition: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.stateNames = stateNames
        self.onSelectState = onSelectState
        self.onResumeAutonomy = onResumeAutonomy
        self.onResetPosition = onResetPosition

        configureButton()
        statusItem.menu = buildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        if let symbol = NSImage(systemSymbolName: "cat", accessibilityDescription: "Pixel Cat") {
            symbol.isTemplate = true
            button.image = symbol
        } else {
            button.title = "Cat"
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        for name in stateNames {
            let item = NSMenuItem(
                title: name.capitalized,
                action: #selector(selectState(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = name
            menu.addItem(item)
            stateItems[name] = item
        }

        menu.addItem(.separator())

        autonomyItem = NSMenuItem(
            title: "Let the Cat Decide",
            action: #selector(resumeAutonomy),
            keyEquivalent: ""
        )
        autonomyItem.target = self
        menu.addItem(autonomyItem)

        menu.addItem(.separator())

        let reset = NSMenuItem(
            title: "Reset Position",
            action: #selector(resetPosition),
            keyEquivalent: ""
        )
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Pixel Cat",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    /// Marks the active state, and the autonomy item when the cat is choosing
    /// for itself.
    func refresh(currentState: String, isAutonomous: Bool) {
        for (name, item) in stateItems {
            item.state = (name == currentState) ? .on : .off
        }
        autonomyItem.state = isAutonomous ? .on : .off
    }

    @objc private func selectState(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        onSelectState(name)
    }

    @objc private func resumeAutonomy() {
        onResumeAutonomy()
    }

    @objc private func resetPosition() {
        onResetPosition()
    }
}
