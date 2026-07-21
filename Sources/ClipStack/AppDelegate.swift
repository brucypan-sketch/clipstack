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
        // Two instances polling the same history file silently undo each
        // other's writes (last-writer-wins), so refuse to be the second one.
        // Bare debug binaries have no bundle identifier and skip this.
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSLog("ClipStack: another instance is already running; quitting.")
            NSApp.terminate(nil)
            return
        }

        let defaults = UserDefaults.standard
        let maxEntries = (defaults.object(forKey: "maxEntries") as? NSNumber)?.intValue
            ?? ClipHistory.defaultMaxEntries
        history = ClipHistory(fileURL: Self.historyFileURL, maxEntries: maxEntries)
        watcher = ClipboardWatcher { [weak self] text in
            if self?.history.add(text) == false {
                NSLog("ClipStack: copy not recorded (empty or over 1 MB)")
            }
        }
        watcher.start()
        menuController = StatusMenuController(history: history)
        // The poller ticks every 0.5 s, so without this hook a copy made just
        // before opening the menu wouldn't be in it yet.
        menuController.refreshHistory = { [weak self] in
            self?.watcher.checkNow()
        }

        let keyCode = (defaults.object(forKey: "hotKeyCode") as? NSNumber)?.uint32Value
            ?? HotKey.defaultKeyCode
        let modifiers = (defaults.object(forKey: "hotKeyModifiers") as? NSNumber)?.uint32Value
            ?? HotKey.defaultModifiers
        hotKey = HotKey(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.menuController.popUpAtMouse()
        }
        if hotKey == nil {
            let alert = NSAlert()
            alert.messageText = "ClipStack couldn't register its global shortcut"
            alert.informativeText = "Another app may already use this combination. "
                + "The menu bar icon still works, and the shortcut can be changed "
                + "with `defaults write com.brucepan.clipstack hotKeyCode/hotKeyModifiers`."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A debounced save may still be pending; don't lose it.
        history?.flush()
    }
}
