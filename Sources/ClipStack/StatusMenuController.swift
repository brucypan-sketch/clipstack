import AppKit
import ClipStackKit
import ServiceManagement

/// The status item and its menu. Hybrid layout: 5 most recent entries on
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
        // Template image (not the 📋 emoji) so the icon renders monochrome and
        // matches the rest of the system menu bar's SF Symbol glyphs, in both
        // light and dark menu bar tint and when the item is highlighted.
        statusItem.button?.image = Self.templateSymbol("doc.on.clipboard", accessibilityDescription: "ClipStack")
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
            let item = NSMenuItem(title: category.menuLabel, action: nil, keyEquivalent: "")
            item.image = Self.templateSymbol(category.symbolName, accessibilityDescription: category.menuLabel)
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

        let login = NSMenuItem(title: "Start at Login",
                               action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(NSMenuItem(title: "Quit ClipStack",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func entryItem(for entry: ClipEntry) -> NSMenuItem {
        let item = NSMenuItem(title: MenuTitle.display(for: entry.text),
                              action: #selector(restore(_:)), keyEquivalent: "")
        item.image = Self.templateSymbol(entry.category.symbolName, accessibilityDescription: entry.category.menuLabel)
        item.target = self
        item.representedObject = entry.text
        return item
    }

    /// Builds a monochrome template image from an SF Symbol so menu items
    /// match the system's own glyph style instead of colored emoji.
    private static func templateSymbol(_ name: String, accessibilityDescription: String?) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        image?.isTemplate = true
        return image
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

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change login item"
            alert.informativeText = error.localizedDescription
                + "\n\nStart at Login only works when running the installed app "
                + "(~/Applications/ClipStack.app), not a bare debug binary."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
