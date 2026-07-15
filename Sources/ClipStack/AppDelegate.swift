import AppKit
import ClipStackKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var history: ClipHistory!
    private var watcher: ClipboardWatcher!
    private var menuController: StatusMenuController!

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
    }
}
