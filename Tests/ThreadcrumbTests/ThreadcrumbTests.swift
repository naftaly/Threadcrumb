import XCTest
@testable import Threadcrumb

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
final class ThreadcrumbTests: XCTestCase {
    
    let _logger: Threadcrumb = Threadcrumb(identifier: "com.bedroomcode.ThreadcrumbTests")

    func testSimpleOutputSameAsInput() throws {
        _logger.log("abc")
        XCTAssertEqual("abc", _logger.stringLoggingThread())
    }
    
    func testFormattedInput() throws {
        _logger.log("%@ %0.2f", "hello", 12.12)
        XCTAssertEqual("hello_12_12", _logger.stringLoggingThread())
    }
    
    func testInitWithIdentifier() {
        let identifier = "TestThread"
        let threadcrumb = Threadcrumb(identifier: identifier)
        XCTAssertEqual(threadcrumb.identifier, identifier, "The identifier should match the one provided at initialization.")
    }
    
    func testLogWithAllowedCharacters() {
        let threadcrumb = Threadcrumb(identifier: "TestThread")
        let testString = "abc123"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertEqual(loggedString, testString, "Logged string should match the input string when using allowed characters.")
    }
    
    func testLogWithDisallowedCharacters() {
        let threadcrumb = Threadcrumb(identifier: "TestThread")
        let testString = "ABC@123!"
        let expectedString = "abc_123_"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertEqual(loggedString, expectedString, "Disallowed characters should be converted to underscores.")
    }
    
    func testLogFormattedString() {
        let threadcrumb = Threadcrumb(identifier: "TestThread")
        let format = "Test %d %@"
        let value = 123
        let string = "formatted"
        let expectedString = "test_123_formatted"
        threadcrumb.log(format, value, string)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertEqual(loggedString, expectedString, "Formatted string should be logged correctly with allowed characters.")
    }
    
    func testThreadBehavior() {
        let threadcrumb = Threadcrumb(identifier: "TestThread")
        let testString = "threadtest"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertNotEqual(loggedString, "", "Thread should process the logged string and not be empty.")
    }
}
