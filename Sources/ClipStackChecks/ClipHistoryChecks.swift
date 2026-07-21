import Foundation
import ClipStackKit

func runClipHistoryChecks() {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipstack-checks-\(UUID().uuidString)")
    let fileURL = dir.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: dir) }

    let h = ClipHistory(fileURL: fileURL, saveDelay: 0)
    expect(h.entries.isEmpty, "starts empty")
    expect(h.add("first"), "add accepts text")
    h.add("https://x.com")
    expect(h.entries.map(\.text) == ["https://x.com", "first"], "newest first")
    expect(h.entries[0].category == .link, "entry carries category")

    let firstCopiedAt = h.entries.last!.copiedAt
    h.add("first")
    expect(h.entries.map(\.text) == ["first", "https://x.com"], "dedupe moves to top")
    expect(h.entries.count == 2, "dedupe adds no duplicate")
    expect(h.entries[0].copiedAt >= firstCopiedAt, "dedupe refreshes timestamp")

    expect(!h.add(""), "rejects empty")
    expect(!h.add("   \n  "), "rejects whitespace-only")
    expect(!h.add(String(repeating: "x", count: 1_000_001)), "rejects >1MB")
    expect(h.add(String(repeating: "x", count: 10)), "accepts small text")

    for i in 0..<60 { h.add("item \(i)") }
    expect(h.entries.count == 50, "capped at 50")
    expect(h.entries.first?.text == "item 59", "newest kept after cap")

    h.add("bob@example.com")
    expect(h.entries(in: .email).map(\.text) == ["bob@example.com"], "filter by category")

    let h2 = ClipHistory(fileURL: fileURL, saveDelay: 0)
    expect(h2.entries.map(\.text) == h.entries.map(\.text), "round-trip preserves order")
    expect(h2.entries(in: .email).count == 1, "round-trip preserves categories")
    // ISO8601 drops sub-second precision, so compare with 1 s tolerance.
    let savedAt = h.entries.first!.copiedAt
    let loadedAt = h2.entries.first!.copiedAt
    expect(abs(loadedAt.timeIntervalSince(savedAt)) < 1, "round-trip preserves timestamps")

    h2.clear()
    expect(h2.entries.isEmpty, "clear empties list")
    let h3 = ClipHistory(fileURL: fileURL, saveDelay: 0)
    expect(h3.entries.isEmpty, "clear persisted")

    // Corrupt file: starts empty AND the original bytes survive alongside.
    try? "not json{{{".write(to: fileURL, atomically: true, encoding: .utf8)
    let h4 = ClipHistory(fileURL: fileURL, saveDelay: 0)
    expect(h4.entries.isEmpty, "corrupt file -> empty history")
    let corruptURL = fileURL.appendingPathExtension("corrupt")
    expect((try? String(contentsOf: corruptURL, encoding: .utf8)) == "not json{{{",
           "corrupt file preserved aside, not clobbered")

    let h5 = ClipHistory(fileURL: dir.appendingPathComponent("nope.json"), saveDelay: 0)
    expect(h5.entries.isEmpty, "missing file -> empty history")

    let h6 = ClipHistory(fileURL: nil, saveDelay: 0)
    h6.add("mem")
    expect(h6.entries.count == 1, "memory-only mode works")

    // Legacy v1 format (plain string array) migrates, including the cap.
    let legacyURL = dir.appendingPathComponent("legacy.json")
    let manyTexts = (0..<60).map { "item\($0)" } + ["https://legacy.example.com"]
    try? JSONEncoder().encode(manyTexts).write(to: legacyURL)
    let h7 = ClipHistory(fileURL: legacyURL, saveDelay: 0)
    expect(h7.entries.count == 50, "legacy load caps oversized file at maxEntries")
    expect(h7.entries.first?.text == "item0", "legacy load keeps newest after cap")
    expect(h7.entries.last?.text == "item49", "legacy load drops oldest past cap")
    let legacyLinkURL = dir.appendingPathComponent("legacy-link.json")
    try? JSONEncoder().encode(["https://legacy.example.com"]).write(to: legacyLinkURL)
    let h8 = ClipHistory(fileURL: legacyLinkURL, saveDelay: 0)
    expect(h8.entries.first?.category == .link, "legacy load classifies migrated entries")

    // Load re-validates: hand-edited oversized/whitespace entries are dropped.
    let taintedURL = dir.appendingPathComponent("tainted.json")
    let tainted = ["ok", "   ", String(repeating: "x", count: 1_000_001)]
    try? JSONEncoder().encode(tainted).write(to: taintedURL)
    let h9 = ClipHistory(fileURL: taintedURL, saveDelay: 0)
    expect(h9.entries.map(\.text) == ["ok"], "load drops non-storable entries")

    // Debounce: with a long saveDelay nothing hits disk until flush().
    let debounceURL = dir.appendingPathComponent("debounce.json")
    let h10 = ClipHistory(fileURL: debounceURL, saveDelay: 60)
    h10.add("pending")
    expect(!FileManager.default.fileExists(atPath: debounceURL.path),
           "debounced save not yet written")
    h10.flush()
    expect(FileManager.default.fileExists(atPath: debounceURL.path),
           "flush writes pending save")
    let h11 = ClipHistory(fileURL: debounceURL, saveDelay: 0)
    expect(h11.entries.map(\.text) == ["pending"], "flushed save round-trips")

    // Single-entry removal persists immediately.
    let removeURL = dir.appendingPathComponent("remove.json")
    let hr = ClipHistory(fileURL: removeURL, saveDelay: 60)
    hr.add("keep")
    hr.add("drop")
    hr.remove(text: "drop")
    expect(hr.entries.map(\.text) == ["keep"], "remove(text:) drops only that entry")
    hr.remove(text: "not there")
    expect(hr.entries.count == 1, "remove of unknown text is a no-op")
    let hr2 = ClipHistory(fileURL: removeURL, saveDelay: 0)
    expect(hr2.entries.map(\.text) == ["keep"], "remove persists without waiting for debounce")

    // Custom cap: both add-side and load-side trimming honor it.
    let smallURL = dir.appendingPathComponent("small.json")
    let h12 = ClipHistory(fileURL: smallURL, saveDelay: 0, maxEntries: 3)
    for i in 0..<5 { h12.add("s\(i)") }
    expect(h12.entries.map(\.text) == ["s4", "s3", "s2"], "custom maxEntries caps adds")
    let h13 = ClipHistory(fileURL: smallURL, saveDelay: 0, maxEntries: 2)
    expect(h13.entries.map(\.text) == ["s4", "s3"], "custom maxEntries caps load")

    // Pinning: exempt from cap and expiry, persisted, toggleable.
    let pinURL = dir.appendingPathComponent("pin.json")
    let hp = ClipHistory(fileURL: pinURL, saveDelay: 0, maxEntries: 3)
    hp.add("keeper")
    hp.togglePin(text: "keeper")
    for i in 0..<5 { hp.add("p\(i)") }
    expect(hp.entries.contains { $0.text == "keeper" && $0.pinned },
           "pinned entry survives the cap")
    expect(hp.entries.count(where: { !$0.pinned }) == 3,
           "cap counts only unpinned entries")
    let hpReload = ClipHistory(fileURL: pinURL, saveDelay: 0, maxEntries: 3)
    expect(hpReload.entries.contains { $0.text == "keeper" && $0.pinned },
           "pinned flag round-trips")
    hpReload.add("keeper")
    expect(hpReload.entries.first?.pinned == true, "re-copy keeps entry pinned")
    hpReload.togglePin(text: "keeper")
    expect(hpReload.entries.first?.pinned == false, "unpin works")

    let hpAge = ClipHistory(fileURL: nil, saveDelay: 0, maxAge: 0.0001)
    hpAge.add("pinned forever")
    hpAge.togglePin(text: "pinned forever")
    Thread.sleep(forTimeInterval: 0.01)
    hpAge.pruneExpired()
    expect(hpAge.entries.count == 1, "pinned entries never expire")

    // Files written before pinning existed (no pinned key) still decode.
    let prePinURL = dir.appendingPathComponent("prepin.json")
    try? #"[{"text":"old","category":"text","copiedAt":"2026-07-20T00:00:00Z"}]"#
        .write(to: prePinURL, atomically: true, encoding: .utf8)
    let hPre = ClipHistory(fileURL: prePinURL, saveDelay: 0, maxAge: nil)
    expect(hPre.entries.first?.text == "old" && hPre.entries.first?.pinned == false,
           "pre-pinning files decode with pinned defaulting to false")

    // Expiry: entries older than maxAge are pruned at load; nil never expires.
    let agedURL = dir.appendingPathComponent("aged.json")
    let aged = [
        ClipEntry(text: "fresh", category: .text),
        ClipEntry(text: "stale", category: .text,
                  copiedAt: Date(timeIntervalSinceNow: -10 * 86_400)),
    ]
    let agedEncoder = JSONEncoder()
    agedEncoder.dateEncodingStrategy = .iso8601
    try? agedEncoder.encode(aged).write(to: agedURL)
    let h14 = ClipHistory(fileURL: agedURL, saveDelay: 0, maxAge: 7 * 86_400)
    expect(h14.entries.map(\.text) == ["fresh"], "expired entries pruned at load")
    try? agedEncoder.encode(aged).write(to: agedURL)
    let h15 = ClipHistory(fileURL: agedURL, saveDelay: 0, maxAge: nil)
    expect(h15.entries.count == 2, "maxAge nil never expires")
    let h16 = ClipHistory(fileURL: nil, saveDelay: 0, maxAge: 0.0001)
    h16.add("gone soon")
    Thread.sleep(forTimeInterval: 0.01)
    h16.pruneExpired()
    expect(h16.entries.isEmpty, "pruneExpired drops aged entries")

    // Saved file is 0600 from the first write (no chmod window).
    let perms = (try? FileManager.default.attributesOfItem(atPath: debounceURL.path))?[.posixPermissions] as? Int
    expect(perms == 0o600, "history file written with 0600 permissions")
}
