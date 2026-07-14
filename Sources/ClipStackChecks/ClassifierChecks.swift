import ClipStackKit

func runClassifierChecks() {
    expect(Classifier.classify("https://github.com/anthropics") == .link, "https URL -> link")
    expect(Classifier.classify("www.example.com") == .link, "www URL -> link")
    expect(Classifier.classify("  https://x.com  ") == .link, "padded URL still link")
    expect(Classifier.classify("alice@example.com") == .email, "bare email -> email")
    expect(Classifier.classify("mailto:alice@example.com") == .email, "mailto URL -> email")
    expect(Classifier.classify("+1 604 555 0199") == .phone, "intl phone -> phone")
    expect(Classifier.classify("(604) 555-0199") == .phone, "US phone -> phone")
    expect(Classifier.classify("hello world") == .text, "prose -> text")
    expect(Classifier.classify("see https://x.com for info") == .text, "prose containing URL -> text")
    expect(Classifier.classify("def main():\n    print(\"hi\")") == .text, "code -> text")
    expect(Classifier.classify("") == .text, "empty -> text")
}
