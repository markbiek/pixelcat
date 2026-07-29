import AppKit

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let animalNames: [String]
    private var stateNames: [String]
    private let onSelectAnimal: (String) -> Void
    private let onSelectState: (String) -> Void
    private let onResumeAutonomy: () -> Void
    private let onResetPosition: () -> Void

    private var animalItems: [String: NSMenuItem] = [:]
    private var stateItems: [String: NSMenuItem] = [:]
    private var autonomyItem: NSMenuItem!

    init(
        animalNames: [String],
        stateNames: [String],
        onSelectAnimal: @escaping (String) -> Void,
        onSelectState: @escaping (String) -> Void,
        onResumeAutonomy: @escaping () -> Void,
        onResetPosition: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.animalNames = animalNames
        self.stateNames = stateNames
        self.onSelectAnimal = onSelectAnimal
        self.onSelectState = onSelectState
        self.onResumeAutonomy = onResumeAutonomy
        self.onResetPosition = onResetPosition

        configureButton()
        rebuildMenu()
    }

    /// Swaps in a new state vocabulary after an animal change.
    func setStates(_ names: [String]) {
        stateNames = names
        rebuildMenu()
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

    private func rebuildMenu() {
        animalItems.removeAll()
        stateItems.removeAll()

        let menu = NSMenu()

        let animalItem = NSMenuItem(title: "Animal", action: nil, keyEquivalent: "")
        let animalMenu = NSMenu()
        for name in animalNames {
            let item = NSMenuItem(
                title: name.capitalized,
                action: #selector(selectAnimal(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = name
            animalMenu.addItem(item)
            animalItems[name] = item
        }
        animalItem.submenu = animalMenu
        menu.addItem(animalItem)

        menu.addItem(.separator())

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

        statusItem.menu = menu
    }

    /// Marks the active animal and state, and the autonomy item when the cat
    /// is choosing for itself.
    func refresh(currentAnimal: String, currentState: String, isAutonomous: Bool) {
        for (name, item) in animalItems {
            item.state = (name == currentAnimal) ? .on : .off
        }
        for (name, item) in stateItems {
            item.state = (name == currentState) ? .on : .off
        }
        autonomyItem.state = isAutonomous ? .on : .off
    }

    @objc private func selectAnimal(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        onSelectAnimal(name)
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
