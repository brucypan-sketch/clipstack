import AppKit
import ClipStackKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var history: ClipHistory!
    private var watcher: ClipboardWatcher!
    private var menuController: StatusMenuController!
    private var hotKey: HotKey?

    static var historyFileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ClipStack/history.json")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        history = ClipHistory(fileURL: Self.historyFileURL)
        watcher = ClipboardWatcher { [weak self] text in
            self?.history.add(text)
        }
        watcher.start()
        menuController = StatusMenuController(history: history)
        hotKey = HotKey { [weak self] in
            self?.menuController.popUpAtMouse()
        }
        if hotKey == nil {
            let alert = NSAlert()
            alert.messageText = "ClipStack couldn't register ⌘⇧V"
            alert.informativeText = "Another app may already use this shortcut. "
                + "The menu bar icon still works."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
