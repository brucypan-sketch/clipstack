import AppKit
import ClipStackKit

/// The 📋 status item and its menu. Hybrid layout: 5 most recent entries on
/// top, then one submenu per non-empty category, then app controls. The menu
/// is rebuilt every time it opens (menuNeedsUpdate) or is popped by hotkey.
final class StatusMenuController: NSObject, NSMenuDelegate {
    static let recentCount = 5

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let history: ClipHistory

    init(history: ClipHistory) {
        self.history = history
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.title = "📋"
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func popUpAtMouse() {
        rebuild()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func rebuild() {
        menu.removeAllItems()

        for entry in history.entries.prefix(Self.recentCount) {
            menu.addItem(entryItem(for: entry))
        }
        if !history.entries.isEmpty {
            menu.addItem(.separator())
        }

        for category in ClipCategory.allCases {
            let categoryEntries = history.entries(in: category)
            guard !categoryEntries.isEmpty else { continue }
            let submenu = NSMenu()
            for entry in categoryEntries {
                submenu.addItem(entryItem(for: entry))
            }
            let item = NSMenuItem(title: "\(category.icon) \(category.menuLabel)",
                                  action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
        if !history.entries.isEmpty {
            menu.addItem(.separator())
        }

        let clear = NSMenuItem(title: "Clear History",
                               action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(NSMenuItem(title: "Quit ClipStack",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func entryItem(for entry: ClipEntry) -> NSMenuItem {
        let item = NSMenuItem(title: "\(entry.category.icon) \(MenuTitle.display(for: entry.text))",
                              action: #selector(restore(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = entry.text
        return item
    }

    @objc private func restore(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @objc private func clearHistory() {
        history.clear()
    }
}
