import Foundation
import ClipStackKit

func runClipHistoryChecks() {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipstack-checks-\(UUID().uuidString)")
    let fileURL = dir.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: dir) }

    let h = ClipHistory(fileURL: fileURL)
    expect(h.entries.isEmpty, "starts empty")
    expect(h.add("first"), "add accepts text")
    h.add("https://x.com")
    expect(h.entries.map(\.text) == ["https://x.com", "first"], "newest first")
    expect(h.entries[0].category == .link, "entry carries category")

    h.add("first")
    expect(h.entries.map(\.text) == ["first", "https://x.com"], "dedupe moves to top")
    expect(h.entries.count == 2, "dedupe adds no duplicate")

    expect(!h.add(""), "rejects empty")
    expect(!h.add("   \n  "), "rejects whitespace-only")
    expect(!h.add(String(repeating: "x", count: 1_000_001)), "rejects >1MB")
    expect(h.add(String(repeating: "x", count: 10)), "accepts small text")

    for i in 0..<60 { h.add("item \(i)") }
    expect(h.entries.count == 50, "capped at 50")
    expect(h.entries.first?.text == "item 59", "newest kept after cap")

    h.add("bob@example.com")
    expect(h.entries(in: .email).map(\.text) == ["bob@example.com"], "filter by category")

    let h2 = ClipHistory(fileURL: fileURL)
    expect(h2.entries.map(\.text) == h.entries.map(\.text), "round-trip preserves order")
    expect(h2.entries(in: .email).count == 1, "categories recomputed on load")

    h2.clear()
    expect(h2.entries.isEmpty, "clear empties list")
    let h3 = ClipHistory(fileURL: fileURL)
    expect(h3.entries.isEmpty, "clear persisted")

    try? "not json{{{".write(to: fileURL, atomically: true, encoding: .utf8)
    let h4 = ClipHistory(fileURL: fileURL)
    expect(h4.entries.isEmpty, "corrupt file -> empty history")
    let h5 = ClipHistory(fileURL: dir.appendingPathComponent("nope.json"))
    expect(h5.entries.isEmpty, "missing file -> empty history")

    let h6 = ClipHistory(fileURL: nil)
    h6.add("mem")
    expect(h6.entries.count == 1, "memory-only mode works")
}
