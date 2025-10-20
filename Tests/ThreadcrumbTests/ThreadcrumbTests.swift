import XCTest
@testable import Threadcrumb

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
final class ThreadcrumbTests: XCTestCase {
    
    var threadcrumb: Threadcrumb!
    
    override func setUp() {
        super.setUp()
        threadcrumb = Threadcrumb(identifier: "com.bedroomcode.ThreadcrumbTests")
    }

    override func tearDown() {
        threadcrumb = nil
        super.tearDown()
    }
    
    func testEmptyString() throws {
        threadcrumb.log("")
        XCTAssertEqual("", threadcrumb.stringLoggingThread())
    }
    
    func testSimpleOutputSameAsInput() throws {
        threadcrumb.log("abc")
        XCTAssertEqual("abc", threadcrumb.stringLoggingThread())
    }

    func testInitWithIdentifier() {
        XCTAssertEqual(threadcrumb.identifier, "com.bedroomcode.ThreadcrumbTests", "The identifier should match the one provided at initialization.")
    }
    
    func testLogWithAllowedCharacters() {
        let testString = "abc123"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertEqual(loggedString, testString, "Logged string should match the input string when using allowed characters.")
    }
    
    func testLogWithDisallowedCharacters() {
        let testString = "ABC@123!"
        let expectedString = "abc_123_"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertEqual(loggedString, expectedString, "Disallowed characters should be converted to underscores.")
    }

    func testThreadBehavior() {
        let testString = "threadtest"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertNotEqual(loggedString, "", "Thread should process the logged string and not be empty.")
    }
    
    func testConcurrency() {
        // Avoid capturing `self` (XCTestCase) inside the @Sendable closure by copying the needed reference.
        guard let logger = threadcrumb else {
            XCTFail("threadcrumb was nil")
            return
        }
        DispatchQueue.concurrentPerform(iterations: 1000) { [logger] _ in
            logger.log(String.random(Int.random(in: 0...1000)))
        }
    }
}

extension String {

    static func random(_ length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    static func randomDisallowed(_ length: Int) -> String {
        let characters = "!@#$%^&*()"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

}
