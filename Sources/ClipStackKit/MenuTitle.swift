import Foundation

/// One-line menu previews: trimmed for display only (stored text is restored
/// verbatim), newlines shown as ⏎, truncated to 50 chars with an ellipsis.
public enum MenuTitle {
    public static let maxLength = 50

    public static func display(for text: String) -> String {
        let oneLine = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "⏎")
            .replacingOccurrences(of: "\n", with: "⏎")
            .replacingOccurrences(of: "\r", with: "⏎")
        guard oneLine.count > maxLength else { return oneLine }
        return String(oneLine.prefix(maxLength)) + "…"
    }
}
