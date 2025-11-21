//
//  Threadcrumb.swift
//
//  Created by Alexander Cohen on 2/13/24.
//

import Foundation
import os

/// A utility that encodes a short identifier into the current thread's call stack so it can be recovered later.
///
/// Threadcrumb spins up a dedicated background thread. When you call `log(_:)`, it sanitizes the input string into
/// a sequence of allowed characters and triggers the thread to execute a chain of uniquely-named functions—one per
/// character. The resulting call stack contains those function names, which can be parsed back into the original
/// identifier for diagnostics or testing.
///
/// Synchronization is coordinated with two semaphores:
/// - `_logSemaphore` signals the thread that new work is available.
/// - `_completedSemaphore` signals the caller that the stack capture is complete.
///
/// Usage:
/// ```swift
/// let tc = Threadcrumb(identifier: "network_login")
/// tc.log("cache_hit")
/// // later, read back the encoded breadcrumb from the thread's call stack (see testing helper below)
/// ```
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public final class Threadcrumb: @unchecked Sendable {
    /// The identifier for the thread.
    public let identifier: String

    /// Create a Threadcrumb identified by the name `identifier`,
    /// which will be used to name the thread being logged to.
    ///
    /// The initializer creates and starts a dedicated background thread,
    /// naming it after the provided identifier.
    ///
    /// - Parameter identifier: The name used to identify the thread.
    public init(identifier: String) {
        self.identifier = identifier

        // Create local references for clarity and start a dedicated thread that waits for work.
        let logSem = _logSemaphore
        let completeSemaphore = _completedSemaphore
        _thread = Thread { [weak self] in
            let thread = Thread.current

            // first time around just wait until we're signaled
            logSem.wait()

            while !thread.isCancelled {
                guard let self else {
                    completeSemaphore.signal()
                    break
                }
                THREAD_CRUMB_BEGIN(self, _log)
            }
        }
        _thread?.name = self.identifier
        // Set a larger stack size to handle deep call stacks (up to 256 characters)
        // 1MB to comfortably handle the recursion depth
        _thread?.stackSize = 1024 * 1024
        _thread?.start()
    }

    /// During teardown, cancel the thread and signal any waiting semaphore to allow a clean exit.
    deinit {
        _thread?.cancel()
        _logSemaphore.signal()
    }

    /// Logs a string to the thread named `.identifier`.
    ///
    /// This method blocks until the stack has been captured and the breadcrumb has been embedded in the call stack.
    ///
    /// - Parameter value: The string to be logged. Maximum length is 256 characters; longer strings will be truncated.
    /// Only the following characters are allowed: `0123456789abcdefghijklmnopqrstuvwxyz_`,
    /// anything else will be converted to `_`.
    public func log(_ value: String) {
        // Normalize the value to lowercase a-z, 0-9, and underscore because these map to the available function
        // symbols.
        // Single-pass validation with early termination at 256 characters for efficiency.
        // Store scalars directly to avoid String allocations.
        var validatedScalars: [UInt32] = []
        validatedScalars.reserveCapacity(min(value.count, 256))

        for char in value {
            if validatedScalars.count >= 256 {
                break
            }

            let lowerChar = char.lowercased()
            if let scalar = lowerChar.unicodeScalars.first?.value,
               (scalar >= 48 && scalar <= 57) || // 0-9
               (scalar >= 97 && scalar <= 122) || // a-z
               scalar == 95
            { // _
                validatedScalars.append(scalar)
            } else {
                validatedScalars.append(95) // '_'
            }
        }

        // Synchronization pattern:
        // - Only one log() operation runs at a time, serialized by _lock.
        // - The background thread never acquires _lock (only reads _log).
        // - Semaphores coordinate with the background thread to signal work availability and completion.
        _lock.lock()

        _callStackReturnAddresses = nil
        _log = validatedScalars

        // Signal the background thread to process _log and build stack
        _logSemaphore.signal()

        // Wait for the background thread to complete stack capture
        _completedSemaphore.wait()

        _lock.unlock()
    }

    /// Returns the captured call stack symbols as an array of strings.
    ///
    /// This method provides access to the call stack symbols computed from the return addresses captured during the
    /// most recent `log()` call.
    /// The symbols contain the function names and addresses that form the breadcrumb chain.
    ///
    /// - Returns: An array of stack symbol strings, or an empty array if no stack has been captured yet.
    public func callStackSymbols() -> [String] {
        let addresses: [UInt64] = _lock.withLock { _callStackReturnAddresses ?? [] }

        return addresses.enumerated().map { index, address in
            var info = Dl_info()
            let addr = UnsafeRawPointer(bitPattern: UInt(address))

            if dladdr(addr, &info) != 0, let sname = info.dli_sname {
                let symbolName = String(cString: sname)
                let offset = UInt64(bitPattern: Int64(Int(bitPattern: addr) - Int(bitPattern: info.dli_saddr)))
                let imageName = info.dli_fname
                    .map { String(cString: $0).split(separator: "/").last.map(String.init) ?? "" } ?? ""

                return String(format: "%-4d%-35s 0x%016llx %@ + %llu", index, imageName, address, symbolName, offset)
            } else {
                return String(format: "%-4d%-35s 0x%016llx", index, "", address)
            }
        }
    }

    /// Returns the captured call stack return addresses as an array of UInt64 values.
    ///
    /// This method provides access to the raw return addresses that were captured during the most recent `log()` call.
    /// These numeric addresses correspond to the instruction pointers in the call stack.
    ///
    /// - Returns: An array of return addresses as UInt64, or an empty array if no stack has been captured yet.
    public func callStackReturnAddresses() -> [UInt64] {
        _lock.withLock {
            _callStackReturnAddresses ?? []
        }
    }

    // MARK: - Private Properties

    /// Properties backing the synchronization and state handoff between the caller and the background thread.

    /// Serializes calls to `log()` and protects handoff state.
    fileprivate let _lock: OSAllocatedUnfairLock = .init()

    /// The sanitized character scalars to encode as a breadcrumb.
    private var _log: [UInt32] = []

    /// The dedicated worker thread that processes logged values.
    private var _thread: Thread?

    /// Semaphore that signals new work is available.
    fileprivate let _logSemaphore = DispatchSemaphore(value: 0)

    /// Semaphore that signals completion of stack capture.
    fileprivate let _completedSemaphore = DispatchSemaphore(value: 0)

    /// The latest captured call stack return addresses from the background thread.
    fileprivate var _callStackReturnAddresses: [UInt64]?
}

// MARK: - Log start and end

/// Helper function that dispatches to the next character function based on the input scalar value.
/// This function is transparent (always inlined, even in debug) to avoid appearing in the call stack.
/// Uses an index to avoid O(n) array mutations on each call.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_transparent
private func _next(_ tc: Threadcrumb, _ values: [UInt32], _ index: Int) {
    guard index < values.count else {
        THREAD_CRUMB_END(tc)
        return
    }
    let scalar = values[index]
    let nextIndex = index + 1
    switch scalar {
    case 48: THREAD_CRUMB__0(tc, values, nextIndex) // '0'
    case 49: THREAD_CRUMB__1(tc, values, nextIndex) // '1'
    case 50: THREAD_CRUMB__2(tc, values, nextIndex) // '2'
    case 51: THREAD_CRUMB__3(tc, values, nextIndex) // '3'
    case 52: THREAD_CRUMB__4(tc, values, nextIndex) // '4'
    case 53: THREAD_CRUMB__5(tc, values, nextIndex) // '5'
    case 54: THREAD_CRUMB__6(tc, values, nextIndex) // '6'
    case 55: THREAD_CRUMB__7(tc, values, nextIndex) // '7'
    case 56: THREAD_CRUMB__8(tc, values, nextIndex) // '8'
    case 57: THREAD_CRUMB__9(tc, values, nextIndex) // '9'
    case 97: THREAD_CRUMB__a(tc, values, nextIndex) // 'a'
    case 98: THREAD_CRUMB__b(tc, values, nextIndex) // 'b'
    case 99: THREAD_CRUMB__c(tc, values, nextIndex) // 'c'
    case 100: THREAD_CRUMB__d(tc, values, nextIndex) // 'd'
    case 101: THREAD_CRUMB__e(tc, values, nextIndex) // 'e'
    case 102: THREAD_CRUMB__f(tc, values, nextIndex) // 'f'
    case 103: THREAD_CRUMB__g(tc, values, nextIndex) // 'g'
    case 104: THREAD_CRUMB__h(tc, values, nextIndex) // 'h'
    case 105: THREAD_CRUMB__i(tc, values, nextIndex) // 'i'
    case 106: THREAD_CRUMB__j(tc, values, nextIndex) // 'j'
    case 107: THREAD_CRUMB__k(tc, values, nextIndex) // 'k'
    case 108: THREAD_CRUMB__l(tc, values, nextIndex) // 'l'
    case 109: THREAD_CRUMB__m(tc, values, nextIndex) // 'm'
    case 110: THREAD_CRUMB__n(tc, values, nextIndex) // 'n'
    case 111: THREAD_CRUMB__o(tc, values, nextIndex) // 'o'
    case 112: THREAD_CRUMB__p(tc, values, nextIndex) // 'p'
    case 113: THREAD_CRUMB__q(tc, values, nextIndex) // 'q'
    case 114: THREAD_CRUMB__r(tc, values, nextIndex) // 'r'
    case 115: THREAD_CRUMB__s(tc, values, nextIndex) // 's'
    case 116: THREAD_CRUMB__t(tc, values, nextIndex) // 't'
    case 117: THREAD_CRUMB__u(tc, values, nextIndex) // 'u'
    case 118: THREAD_CRUMB__v(tc, values, nextIndex) // 'v'
    case 119: THREAD_CRUMB__w(tc, values, nextIndex) // 'w'
    case 120: THREAD_CRUMB__x(tc, values, nextIndex) // 'x'
    case 121: THREAD_CRUMB__y(tc, values, nextIndex) // 'y'
    case 122: THREAD_CRUMB__z(tc, values, nextIndex) // 'z'
    case 95: THREAD_CRUMB___(tc, values, nextIndex) // '_'
    default: THREAD_CRUMB_END(tc)
    }
}

/// Starts the per-character function chain by dispatching on the first scalar.
/// Recurses until all scalars are exhausted and then calls `THREAD_CRUMB_END`.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB_BEGIN") @inline(never) @_optimize(none)
private func THREAD_CRUMB_BEGIN(_ tc: Threadcrumb, _ inputValues: [UInt32]) {
    _next(tc, inputValues, 0)
}

/// Captures the call stack, signals completion to the caller, and waits for the next piece of work.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB_END") @inline(never) @_optimize(none)
private func THREAD_CRUMB_END(_ tc: Threadcrumb) {
    tc._callStackReturnAddresses = Thread.callStackReturnAddresses.map(\.uint64Value)
    tc._completedSemaphore.signal()
    tc._logSemaphore.wait()
}

// MARK: - Character implementations

/// Handles the '0' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__0") @inline(never) @_optimize(none)
private func THREAD_CRUMB__0(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '1' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__1") @inline(never) @_optimize(none)
private func THREAD_CRUMB__1(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '2' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__2") @inline(never) @_optimize(none)
private func THREAD_CRUMB__2(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '3' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__3") @inline(never) @_optimize(none)
private func THREAD_CRUMB__3(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '4' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__4") @inline(never) @_optimize(none)
private func THREAD_CRUMB__4(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '5' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__5") @inline(never) @_optimize(none)
private func THREAD_CRUMB__5(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '6' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__6") @inline(never) @_optimize(none)
private func THREAD_CRUMB__6(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '7' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__7") @inline(never) @_optimize(none)
private func THREAD_CRUMB__7(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '8' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__8") @inline(never) @_optimize(none)
private func THREAD_CRUMB__8(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '9' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__9") @inline(never) @_optimize(none)
private func THREAD_CRUMB__9(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'a' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__a") @inline(never) @_optimize(none)
private func THREAD_CRUMB__a(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'b' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__b") @inline(never) @_optimize(none)
private func THREAD_CRUMB__b(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'c' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__c") @inline(never) @_optimize(none)
private func THREAD_CRUMB__c(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'd' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__d") @inline(never) @_optimize(none)
private func THREAD_CRUMB__d(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'e' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__e") @inline(never) @_optimize(none)
private func THREAD_CRUMB__e(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'f' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__f") @inline(never) @_optimize(none)
private func THREAD_CRUMB__f(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'g' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__g") @inline(never) @_optimize(none)
private func THREAD_CRUMB__g(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'h' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__h") @inline(never) @_optimize(none)
private func THREAD_CRUMB__h(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'i' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__i") @inline(never) @_optimize(none)
private func THREAD_CRUMB__i(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'j' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__j") @inline(never) @_optimize(none)
private func THREAD_CRUMB__j(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'k' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__k") @inline(never) @_optimize(none)
private func THREAD_CRUMB__k(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'l' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__l") @inline(never) @_optimize(none)
private func THREAD_CRUMB__l(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'm' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__m") @inline(never) @_optimize(none)
private func THREAD_CRUMB__m(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'n' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__n") @inline(never) @_optimize(none)
private func THREAD_CRUMB__n(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'o' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__o") @inline(never) @_optimize(none)
private func THREAD_CRUMB__o(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'p' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__p") @inline(never) @_optimize(none)
private func THREAD_CRUMB__p(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'q' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__q") @inline(never) @_optimize(none)
private func THREAD_CRUMB__q(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'r' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__r") @inline(never) @_optimize(none)
private func THREAD_CRUMB__r(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 's' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__s") @inline(never) @_optimize(none)
private func THREAD_CRUMB__s(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 't' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__t") @inline(never) @_optimize(none)
private func THREAD_CRUMB__t(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'u' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__u") @inline(never) @_optimize(none)
private func THREAD_CRUMB__u(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'v' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__v") @inline(never) @_optimize(none)
private func THREAD_CRUMB__v(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'w' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__w") @inline(never) @_optimize(none)
private func THREAD_CRUMB__w(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'x' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__x") @inline(never) @_optimize(none)
private func THREAD_CRUMB__x(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'y' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__y") @inline(never) @_optimize(none)
private func THREAD_CRUMB__y(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the 'z' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__z") @inline(never) @_optimize(none)
private func THREAD_CRUMB__z(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

/// Handles the '_' character in the breadcrumb and dispatches to the next character or ends the chain.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB___") @inline(never) @_optimize(none)
private func THREAD_CRUMB___(_ tc: Threadcrumb, _ inputValues: [UInt32], _ index: Int) {
    _next(tc, inputValues, index)
}

// MARK: - For testing only

// Anything below here should be used for testing purposes only

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
extension Threadcrumb {
    /// Extracts the encoded breadcrumb from the captured call stack by locating frames between
    /// `THREAD_CRUMB_END` and `THREAD_CRUMB_BEGIN` and parsing the symbol names.
    func stringLoggingThread() -> String {
        let symbols = callStackSymbols()

        // Find indices of frames marking the start and end of the encoded breadcrumb in the stack.
        // If missing, return empty string.
        guard
            let lowIndex = symbols.lastIndex(where: {
                $0.contains("THREAD_CRUMB_END")
            }),
            let highIndex = symbols.firstIndex(where: {
                $0.contains("THREAD_CRUMB_BEGIN")
            })
        else {
            return ""
        }

        // _symbols_ is an array of string similar to the following:
        // "1   ThreadcrumbTests                    0x0000000102d754b0 THREAD_CRUMB__c + 644"
        // We want to get everything after `THREAD_CRUMB_` and before the next space.
        // In C, I'd just use backtrace and backtrace_symbols, but this will do just fine.
        let relevantSymbols = symbols[lowIndex + 1 ..< highIndex].map {
            String($0)
        }.filter { $0.contains("THREAD_CRUMB__") }
        let extractedSymbols = relevantSymbols.filter {
            $0.contains("THREAD_CRUMB__")
        }.map {
            guard
                let symbolName = $0.split(separator: " THREAD_CRUMB__").last?
                .split(separator: " +").first
            else {
                return ""
            }
            return String(symbolName)
        }

        return extractedSymbols.reversed().joined()
    }
}
