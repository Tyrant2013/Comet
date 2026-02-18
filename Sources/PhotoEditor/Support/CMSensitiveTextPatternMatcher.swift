import Foundation

public struct CMSensitiveTextPatternMatcher: Sendable {
    private let regexes: [NSRegularExpression]

    public init() {
        regexes = [
            try! NSRegularExpression(pattern: #"\b\d{16,19}\b"#),
            try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#),
            try! NSRegularExpression(pattern: #"\b1[3-9]\d{9}\b"#),
            try! NSRegularExpression(pattern: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"\b(?:\d[ -]?){6,}\d\b"#)
        ]
    }

    public func containsSensitiveText(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for regex in regexes where regex.firstMatch(in: text, range: range) != nil {
            return true
        }
        return false
    }
}
