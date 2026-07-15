import ClipStackKit

func runMenuTitleChecks() {
    expect(MenuTitle.display(for: "hello") == "hello", "short text unchanged")
    expect(MenuTitle.display(for: "  padded  ") == "padded", "whitespace trimmed for display")
    expect(MenuTitle.display(for: "line1\nline2") == "line1⏎line2", "newline rendered as ⏎")
    expect(MenuTitle.display(for: "a\r\nb\rc") == "a⏎b⏎c", "CRLF and CR rendered as ⏎")
    let long = String(repeating: "a", count: 60)
    expect(MenuTitle.display(for: long) == String(repeating: "a", count: 50) + "…",
           "truncated to 50 + ellipsis")
    expect(MenuTitle.display(for: String(repeating: "b", count: 50)).count == 50,
           "exactly 50 not truncated")
}
