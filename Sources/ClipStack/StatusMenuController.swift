import AppKit
import ClipStackKit
import ServiceManagement

/// The status item and its menu. Hybrid layout: 5 most recent entries on
/// top, then one submenu per non-empty category, then app controls. The menu
/// is rebuilt every time it opens (menuNeedsUpdate) or is popped by hotkey.
final class StatusMenuController: NSObject, NSMenuDelegate {
    static let recentCount = 5

    /// Called before every rebuild so the owner can pull any not-yet-polled
    /// clipboard change into history first (the watcher ticks at 0.5 s).
    var refreshHistory: (() -> Void)?

    /// Called when the user toggles Pause Capture; receives the new paused
    /// state. The owner starts/stops the watcher accordingly.
    var captureToggled: ((Bool) -> Void)?
    private(set) var capturePaused = false

    private static let copiedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

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
        if !capturePaused {
            refreshHistory?()
        }
        menu.removeAllItems()

        let all = history.entries

        let pinned = all.filter(\.pinned)
        for entry in pinned {
            for item in entryItems(for: entry, keyEquivalent: "", showPin: true) {
                menu.addItem(item)
            }
        }
        if !pinned.isEmpty {
            menu.addItem(.separator())
        }

        let unpinned = all.filter { !$0.pinned }
        for (index, entry) in unpinned.prefix(Self.recentCount).enumerated() {
            // Plain 1–5 key equivalents: with the menu open, a digit restores
            // that entry without reaching for the mouse.
            for item in entryItems(for: entry, keyEquivalent: "\(index + 1)") {
                menu.addItem(item)
            }
        }
        if !unpinned.isEmpty {
            menu.addItem(.separator())
        }

        for category in ClipCategory.allCases {
            let categoryEntries = all.filter { $0.category == category }
            guard !categoryEntries.isEmpty else { continue }
            let submenu = NSMenu()
            for entry in categoryEntries {
                for item in entryItems(for: entry, keyEquivalent: "") {
                    submenu.addItem(item)
                }
            }
            let item = NSMenuItem(title: category.menuLabel, action: nil, keyEquivalent: "")
            item.image = Self.templateSymbol(category.symbolName, accessibilityDescription: category.menuLabel)
            item.submenu = submenu
            menu.addItem(item)
        }
        if !all.isEmpty {
            menu.addItem(.separator())
        }

        let pause = NSMenuItem(title: "Pause Capture",
                               action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = capturePaused ? .on : .off
        menu.addItem(pause)

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

    /// Primary item restores the entry; holding ⌥ swaps in an alternate
    /// (trash icon) that deletes it, holding ⇧ one (pin icon) that pins or
    /// unpins it. Alternates must be added adjacent to the primary with the
    /// same key equivalent for AppKit's alternate mechanism.
    private func entryItems(for entry: ClipEntry, keyEquivalent: String,
                            showPin: Bool = false) -> [NSMenuItem] {
        let title = MenuTitle.display(for: entry.text)
        // Pinned-section rows show the pin instead of the category icon —
        // that's what identifies the section.
        let icon = showPin
            ? Self.templateSymbol("pin", accessibilityDescription: "Pinned")
            : Self.templateSymbol(entry.category.symbolName, accessibilityDescription: entry.category.menuLabel)

        let item = NSMenuItem(title: title,
                              action: #selector(restore(_:)), keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = []
        item.image = icon
        item.target = self
        item.representedObject = entry.text
        item.toolTip = Self.toolTip(for: entry)

        let delete = NSMenuItem(title: title,
                                action: #selector(deleteEntry(_:)), keyEquivalent: keyEquivalent)
        delete.keyEquivalentModifierMask = .option
        delete.isAlternate = true
        delete.image = Self.templateSymbol("trash", accessibilityDescription: "Delete")
        delete.target = self
        delete.representedObject = entry.text
        delete.toolTip = "Delete this entry from history"

        let pin = NSMenuItem(title: title,
                             action: #selector(togglePin(_:)), keyEquivalent: keyEquivalent)
        pin.keyEquivalentModifierMask = .shift
        pin.isAlternate = true
        pin.image = Self.templateSymbol(entry.pinned ? "pin.slash" : "pin",
                                        accessibilityDescription: entry.pinned ? "Unpin" : "Pin")
        pin.target = self
        pin.representedObject = entry.text
        pin.toolTip = entry.pinned
            ? "Unpin (entry becomes subject to the cap and expiry again)"
            : "Pin (entry is kept forever, exempt from the cap and expiry)"

        return [item, delete, pin]
    }

    /// Copy time plus the start of the full text — menu titles truncate at
    /// 50 characters, so hovering is how you inspect a long entry.
    private static func toolTip(for entry: ClipEntry) -> String {
        let header = "Copied \(copiedAtFormatter.string(from: entry.copiedAt))"
        let preview = entry.text.count <= 500
            ? entry.text
            : String(entry.text.prefix(500)) + "…"
        return "\(header)\n\n\(preview)"
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

    @objc private func deleteEntry(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        history.remove(text: text)
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        history.togglePin(text: text)
    }

    @objc private func clearHistory() {
        history.clear()
    }

    @objc private func togglePause() {
        capturePaused.toggle()
        // Dimmed icon is the native "present but inactive" signal, and it
        // stays visible after the menu closes, unlike the checkmark.
        statusItem.button?.appearsDisabled = capturePaused
        captureToggled?(capturePaused)
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
