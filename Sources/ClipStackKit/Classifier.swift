import Foundation

public enum Classifier {
    /// Classifies text: the whole trimmed string must be a single
    /// NSDataDetector match to count as link/email/phone; a sentence merely
    /// containing a URL is still .text. Emails are checked before links
    /// because the detector reports them as mailto: links.
    public static func classify(_ text: String) -> ClipCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }
        let types = NSTextCheckingResult.CheckingType.link.rawValue
                  | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        guard let detector = try? NSDataDetector(types: types) else { return .text }
        let fullRange = NSRange(trimmed.startIndex..., in: trimmed)
        let matches = detector.matches(in: trimmed, options: [], range: fullRange)
        guard matches.count == 1, let match = matches.first, match.range == fullRange else {
            return .text
        }
        switch match.resultType {
        case .link:
            return match.url?.scheme?.lowercased() == "mailto" ? .email : .link
        case .phoneNumber:
            return .phone
        default:
            return .text
        }
    }
}
