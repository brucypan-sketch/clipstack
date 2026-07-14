public enum ClipCategory: String, CaseIterable {
    case link, email, phone, text

    public var icon: String {
        switch self {
        case .link: return "🔗"
        case .email: return "✉️"
        case .phone: return "📞"
        case .text: return "📝"
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
