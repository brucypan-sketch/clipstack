import AppKit
import ClipStackKit

/// Floating search panel over the full history: type to filter (matches
/// anywhere in the full text, not just the visible title), ↑/↓ to select,
/// Enter or double-click to restore, Esc to close. Complements the menu
/// once the history outgrows menu-scanning.
final class SearchPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let history: ClipHistory
    private let refreshHistory: () -> Void

    private var panel: NSPanel?
    private var searchField: NSSearchField!
    private var tableView: NSTableView!
    private var filtered: [ClipEntry] = []

    init(history: ClipHistory, refreshHistory: @escaping () -> Void) {
        self.history = history
        self.refreshHistory = refreshHistory
    }

    func show() {
        refreshHistory()
        if panel == nil {
            buildPanel()
        }
        searchField.stringValue = ""
        applyFilter()
        NSApp.activate(ignoringOtherApps: true)
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(searchField)
    }

    // MARK: - Panel construction

    private func buildPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered, defer: false)
        panel.title = "Search History"
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false

        let field = NSSearchField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholderString = "Search clipboard history"
        field.delegate = self
        self.searchField = field

        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = 22
        table.allowsEmptySelection = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("entry"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(restoreSelected)
        self.tableView = table

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = table
        scroll.hasVerticalScroller = true

        let content = NSView()
        content.addSubview(field)
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            field.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
        self.panel = panel
    }

    // MARK: - Filtering and restore

    private func applyFilter() {
        let query = searchField.stringValue
        filtered = query.isEmpty
            ? history.entries
            : history.entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
        tableView.reloadData()
        if !filtered.isEmpty {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    @objc private func restoreSelected() {
        let row = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        guard row < filtered.count else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(filtered[row].text, forType: .string)
        panel?.close()
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let current = tableView.selectedRow
        let next = min(max(current + delta, 0), filtered.count - 1)
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            restoreSelected()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            panel?.close()
            return true
        default:
            return false
        }
    }

    // MARK: - Table data

    func numberOfRows(in tableView: NSTableView) -> Int {
        filtered.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("entryCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
            ?? Self.makeCell(identifier: identifier)
        let entry = filtered[row]
        cell.textField?.stringValue = MenuTitle.display(for: entry.text)
        let symbolName = entry.pinned ? "pin" : entry.category.symbolName
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: entry.category.menuLabel)
        image?.isTemplate = true
        cell.imageView?.image = image
        cell.toolTip = entry.text.count <= 500 ? entry.text : String(entry.text.prefix(500)) + "…"
        return cell
    }

    private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let image = NSImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        cell.addSubview(image)
        cell.addSubview(label)
        cell.imageView = image
        cell.textField = label
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

/// Utility panels don't take key status or handle Esc by default.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
