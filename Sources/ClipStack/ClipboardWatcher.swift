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

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        let types = pasteboard.types ?? []
        guard !types.contains(where: Self.skippedTypes.contains) else { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        onCopy(text)
    }
}
