import AppKit

/// Polls NSPasteboard.changeCount every 0.5 s (macOS offers no clipboard
/// change notification; the compare is a single Int, effectively free).
final class ClipboardWatcher {
    private static let skippedTypes = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
    ]

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let onCopy: (String) -> Void

    init(onCopy: @escaping (String) -> Void) {
        self.onCopy = onCopy
        self.lastChangeCount = pasteboard.changeCount
    }

    deinit {
        stop()
    }

    func start() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.check()
        }
        self.timer = timer
        // .common, not .default: the default mode is paused during menu
        // tracking and modal alerts, which would silently drop copies made
        // while any menu is open.
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Immediate poll, for callers that need the history current right now
    /// (e.g. just before the menu opens) instead of within 0.5 s.
    func checkNow() {
        check()
    }

    private func check() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        let types = pasteboard.types ?? []
        guard !types.contains(where: Self.skippedTypes.contains) else {
            lastChangeCount = count
            return
        }
        guard let text = pasteboard.string(forType: .string) else {
            lastChangeCount = count
            return
        }
        // The pasteboard can change under us between the reads above; if it
        // did, this text wasn't the content we privacy-checked — drop it and
        // let the next tick re-read from scratch.
        guard pasteboard.changeCount == count else { return }
        lastChangeCount = count
        onCopy(text)
    }
}
