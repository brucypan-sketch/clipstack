import Foundation

public struct ClipEntry: Equatable {
    public let text: String
    public let category: ClipCategory
}

/// Ordered clipboard history, newest first. Persists as a JSON array of
/// strings (index 0 = newest); categories are recomputed on load so the file
/// format stays trivial. fileURL == nil means memory-only mode.
public final class ClipHistory {
    public static let maxEntries = 50
    public static let maxItemBytes = 1_000_000

    public private(set) var entries: [ClipEntry] = []
    private let fileURL: URL?

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        load()
    }

    @discardableResult
    public func add(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard text.utf8.count <= Self.maxItemBytes else { return false }
        if let index = entries.firstIndex(where: { $0.text == text }) {
            let entry = entries.remove(at: index)
            entries.insert(entry, at: 0)
        } else {
            entries.insert(ClipEntry(text: text, category: Classifier.classify(text)), at: 0)
            if entries.count > Self.maxEntries {
                entries.removeLast(entries.count - Self.maxEntries)
            }
        }
        save()
        return true
    }

    public func entries(in category: ClipCategory) -> [ClipEntry] {
        entries.filter { $0.category == category }
    }

    public func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let texts = try? JSONDecoder().decode([String].self, from: data) else { return }
        entries = texts.map { ClipEntry(text: $0, category: Classifier.classify($0)) }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries.map(\.text))
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Memory-only degradation per spec: keep running, log to Console.
            NSLog("ClipStack: failed to save history: \(error)")
        }
    }
}
