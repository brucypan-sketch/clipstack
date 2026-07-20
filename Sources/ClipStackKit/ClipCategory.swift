public enum ClipCategory: String, CaseIterable {
    case link, email, phone, text

    /// SF Symbol name for this category, used for menu item images so they
    /// render as monochrome template glyphs matching the system menu bar.
    public var symbolName: String {
        switch self {
        case .link: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .text: return "doc.plaintext"
        }
    }

    public var menuLabel: String {
        switch self {
        case .link: return "Links"
        case .email: return "Emails"
        case .phone: return "Phone Numbers"
        case .text: return "Other Text"
        }
    }
}
