import Foundation

public struct ClipEntry: Equatable, Codable {
    public let text: String
    public let category: ClipCategory
    public let copiedAt: Date

    public init(text: String, category: ClipCategory, copiedAt: Date = Date()) {
        self.text = text
        self.category = category
        self.copiedAt = copiedAt
    }
}

/// Ordered clipboard history, newest first. Persists as a JSON array of
/// entries (index 0 = newest) with category and timestamp; legacy plain
/// string-array files are migrated on load. fileURL == nil means memory-only.
///
/// Main-thread only: entries is read by the menu and mutated by the watcher,
/// both of which run on the main run loop. Saves are debounced by saveDelay
/// (pass 0 for synchronous saves, e.g. in checks); call flush() before
/// process exit so a pending save isn't lost.
public final class ClipHistory {
    public static let maxEntries = 50
    public static let maxItemBytes = 1_000_000

    public private(set) var entries: [ClipEntry] = []
    private let fileURL: URL?
    private let saveDelay: TimeInterval
    private var pendingSave: DispatchWorkItem?

    public init(fileURL: URL?, saveDelay: TimeInterval = 0.5) {
        self.fileURL = fileURL
        self.saveDelay = saveDelay
        load()
    }

    @discardableResult
    public func add(_ text: String) -> Bool {
        guard Self.isStorable(text) else { return false }
        if let index = entries.firstIndex(where: { $0.text == text }) {
            let old = entries.remove(at: index)
            entries.insert(ClipEntry(text: old.text, category: old.category), at: 0)
        } else {
            entries.insert(ClipEntry(text: text, category: Classifier.classify(text)), at: 0)
            if entries.count > Self.maxEntries {
                entries.removeLast(entries.count - Self.maxEntries)
            }
        }
        scheduleSave()
        return true
    }

    public func entries(in category: ClipCategory) -> [ClipEntry] {
        entries.filter { $0.category == category }
    }

    public func clear() {
        entries = []
        flush()
    }

    /// Cancels any pending debounced save and writes immediately.
    public func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        saveNow()
    }

    private static func isStorable(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.utf8.count <= maxItemBytes
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let stored = try? decoder.decode([ClipEntry].self, from: data) {
            entries = Array(stored.filter { Self.isStorable($0.text) }.prefix(Self.maxEntries))
        } else if let texts = try? JSONDecoder().decode([String].self, from: data) {
            // Legacy format: plain string array, no categories or timestamps.
            entries = texts.filter(Self.isStorable)
                .prefix(Self.maxEntries)
                .map { ClipEntry(text: $0, category: Classifier.classify($0)) }
        } else {
            // Corrupt: preserve the evidence instead of letting the next
            // save() clobber it, then start empty.
            let corruptURL = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: corruptURL)
            try? FileManager.default.moveItem(at: fileURL, to: corruptURL)
            NSLog("ClipStack: history file was corrupt; preserved at \(corruptURL.path)")
        }
    }

    private func scheduleSave() {
        guard fileURL != nil else { return }
        guard saveDelay > 0 else {
            saveNow()
            return
        }
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSave = nil
            self?.saveNow()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: work)
    }

    private func saveNow() {
        guard let fileURL else { return }
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            // Created 0600 from the first byte, then swapped into place — the
            // history is never on disk with wider permissions, unlike
            // write(.atomic) + chmod which leaves a default-permission window.
            let tempURL = dir.appendingPathComponent(".history.json.tmp")
            try? FileManager.default.removeItem(at: tempURL)
            guard FileManager.default.createFile(
                atPath: tempURL.path, contents: data,
                attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    fileURL, withItemAt: tempURL,
                    backupItemName: nil, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: fileURL)
            }
        } catch {
            // Memory-only degradation per spec: keep running, log to Console.
            NSLog("ClipStack: failed to save history: \(error)")
        }
    }
}
