import XCTest
@testable import PhotoEditor

final class CMSensitiveTextPatternMatcherTests: XCTestCase {
    func testPatternMatcherDetectsSensitiveData() {
        let matcher = CMSensitiveTextPatternMatcher()
        XCTAssertTrue(matcher.containsSensitiveText("my email is test@example.com"))
        XCTAssertTrue(matcher.containsSensitiveText("card 1234567890123456"))
        XCTAssertTrue(matcher.containsSensitiveText("ssn 123-45-6789"))
        XCTAssertFalse(matcher.containsSensitiveText("hello world"))
    }
}
