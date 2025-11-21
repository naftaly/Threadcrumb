@testable import Threadcrumb
import XCTest

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
        XCTAssertEqual(
            threadcrumb.identifier,
            "com.bedroomcode.ThreadcrumbTests",
            "The identifier should match the one provided at initialization."
        )
    }

    func testLogWithAllowedCharacters() {
        let testString = "abc123"
        threadcrumb.log(testString)
        let loggedString = threadcrumb.stringLoggingThread()
        XCTAssertEqual(
            loggedString,
            testString,
            "Logged string should match the input string when using allowed characters."
        )
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
        // Note: Strings are capped at 256 characters, and we have 2MB stack to handle deep recursion
        DispatchQueue.concurrentPerform(iterations: 1000) { [logger] _ in
            logger.log(String.random(Int.random(in: 0 ... 300)))
        }
    }

    func testStackTraceContainsExpectedFunctions() {
        let testString = "abc"
        threadcrumb.log(testString)

        // Get the call stack symbols to verify structure
        let symbols = threadcrumb.callStackSymbols()
        XCTAssertFalse(symbols.isEmpty, "Stack symbols should not be empty after logging")

        // Verify THREAD_CRUMB functions appear
        let crumbFunctions = symbols.filter { $0.contains("THREAD_CRUMB__") }
        XCTAssertEqual(crumbFunctions.count, 3, "Should have 3 character functions in stack (a, b, c)")

        // Verify BEGIN and END appear
        XCTAssertTrue(
            symbols.contains(where: { $0.contains("THREAD_CRUMB_BEGIN") }),
            "Stack should contain THREAD_CRUMB_BEGIN"
        )
        XCTAssertTrue(
            symbols.contains(where: { $0.contains("THREAD_CRUMB_END") }),
            "Stack should contain THREAD_CRUMB_END"
        )

        // Verify no thunks or helper functions appear
        XCTAssertFalse(
            symbols.contains(where: { $0.contains("thunk") || $0.lowercased().contains("thunk") }),
            "Stack should not contain thunks"
        )
        XCTAssertFalse(
            symbols.contains(where: { $0.contains("_next") }),
            "Stack should not contain _next helper function"
        )
    }

    func testCallStackReturnAddresses() {
        let testString = "test"
        threadcrumb.log(testString)

        let addresses = threadcrumb.callStackReturnAddresses()
        XCTAssertFalse(addresses.isEmpty, "Return addresses should not be empty after logging")
        XCTAssertTrue(addresses.allSatisfy { $0 > 0 }, "All return addresses should be non-zero")
    }

    func testAllValidCharacters() {
        let allChars = "0123456789abcdefghijklmnopqrstuvwxyz_"
        threadcrumb.log(allChars)
        XCTAssertEqual(threadcrumb.stringLoggingThread(), allChars, "All 38 valid characters should be preserved")
    }

    func testMaximumLength() {
        let longString = String(repeating: "a", count: 300)
        threadcrumb.log(longString)
        let logged = threadcrumb.stringLoggingThread()
        XCTAssertEqual(logged.count, 256, "Logged string should be truncated to 256 characters")
        XCTAssertTrue(logged.allSatisfy { $0 == "a" }, "All characters should be 'a'")
    }

    func testReasonableLength() {
        // Test with a reasonable length that won't cause stack issues
        let testString = String(repeating: "test", count: 20) // 80 characters
        threadcrumb.log(testString)
        let logged = threadcrumb.stringLoggingThread()
        XCTAssertEqual(logged.count, 80, "Should log 80 characters")
    }

    func testAllDisallowedCharacters() {
        let disallowedOnly = "!@#$%^&*()"
        threadcrumb.log(disallowedOnly)
        let expected = String(repeating: "_", count: disallowedOnly.count)
        XCTAssertEqual(
            threadcrumb.stringLoggingThread(),
            expected,
            "All disallowed characters should become underscores"
        )
    }

    // MARK: - Performance Tests

    func testPerformanceShortString() {
        measure {
            for _ in 0 ..< 100 {
                threadcrumb.log("hello")
            }
        }
    }

    func testPerformanceMediumString() {
        measure {
            for _ in 0 ..< 100 {
                threadcrumb.log("appstate_active_user")
            }
        }
    }

    func testPerformanceLongString() {
        let longString = String(repeating: "test", count: 20) // 80 chars
        measure {
            for _ in 0 ..< 100 {
                threadcrumb.log(longString)
            }
        }
    }

    func testPerformanceMaximumLength() {
        let maxString = String(repeating: "a", count: 300) // Will be truncated to 256
        measure {
            for _ in 0 ..< 10 {
                threadcrumb.log(maxString)
            }
        }
    }

    func testPerformanceWithSanitization() {
        measure {
            for _ in 0 ..< 100 {
                threadcrumb.log("App:State-Active!@#$%")
            }
        }
    }

    func testPerformanceCallStackAccess() {
        threadcrumb.log("test")
        measure {
            for _ in 0 ..< 1000 {
                _ = threadcrumb.callStackSymbols()
            }
        }
    }

    func testPerformanceReturnAddressesAccess() {
        threadcrumb.log("test")
        measure {
            for _ in 0 ..< 1000 {
                _ = threadcrumb.callStackReturnAddresses()
            }
        }
    }

    func testPerformanceStringExtraction() {
        threadcrumb.log("testbreadcrumb")
        measure {
            for _ in 0 ..< 100 {
                _ = threadcrumb.stringLoggingThread()
            }
        }
    }

    func testPerformanceRapidSequential() {
        measure {
            for i in 0 ..< 50 {
                threadcrumb.log("seq\(i % 10)")
            }
        }
    }

    func testPerformanceAllValidCharacters() {
        let allChars = "0123456789abcdefghijklmnopqrstuvwxyz_"
        measure {
            for _ in 0 ..< 50 {
                threadcrumb.log(allChars)
            }
        }
    }
}

extension String {
    static func random(_ length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< length).compactMap { _ in characters.randomElement() })
    }

    static func randomDisallowed(_ length: Int) -> String {
        let characters = "!@#$%^&*()"
        return String((0 ..< length).compactMap { _ in characters.randomElement() })
    }
}
