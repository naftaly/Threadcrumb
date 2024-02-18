import XCTest
@testable import Threadcrumb

@available(iOS 16.0, *)
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
}
