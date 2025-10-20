//
//  Threadcrumb.swift
//
//  Created by Alexander Cohen on 2/13/24.
//

import Foundation
import os

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
final public class Threadcrumb {
    
    /// The identifier for the thread.
    public let identifier: String
    
    /// Create a Threadcrumb identified by the name `identifier`,
    /// which will be used to name the thread being logged to.
    ///
    /// - Parameter identifier: The name used to identify the thread.
    public init(identifier: String) {
        self.identifier = identifier
        
        let logSem = self._logSemaphore
        self._thread = Thread { [weak self] in
            let thread = Thread.current
            
            // first time around just wait until we're signaled
            logSem.wait()
            
            while (true) {
                guard let self, thread.isExecuting, !thread.isCancelled else {
                    break
                }
                var values: [String] = self._log
                THREAD_CRUMB_BEGIN(self, &values)
            }
        }
        self._thread?.name = self.identifier
        self._thread?.start()
    }

    /// Logs a string to the thread named `.identifier`
    ///
    /// - Parameter value: The string to be logged.
    /// Only the following characters are allowed: `0123456789abcdefghijklmnopqrstuvwxyz_`,
    /// anything else will be converted to `_`.
    public func log(_ value: String) {
        
        // Make a validated string that contains
        // only characters allowed in a Swift function name.
        let validatedCharacters: [String] = value.lowercased()
            .components(separatedBy: Threadcrumb._sDisallowedCharacters)
            .joined(separator: "_")
            .split(separator: "")
            .map { String($0) }

        // set the value
        _lock.lock()
        
        _stack = nil
        _log = validatedCharacters
        
        // signal the thread.
        // by doing so, the thread will begin iterating over `_log`
        // then wait again. this leaves the thread with a
        // stack that describes `_log`.
        _logSemaphore.signal()
        
        // wait for the stack write to complete
        _completedSemaphore.wait()
        
        _lock.unlock()
    }
    
    /// Logs a formatted string to the thread named `.identifier`.
    ///
    /// - Parameters:
    ///   - format: The format string.
    ///   - arguments: The arguments to substitute into `format`.
    public func log(_ format: String, _ arguments: CVarArg...) {
        log(String(format: format, arguments))
    }
    
    // MARK: - Private Properties
    
    static private let _sAllowedCharacters: CharacterSet = CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyz_")
    static private let _sDisallowedCharacters: CharacterSet = _sAllowedCharacters.inverted
    fileprivate let _lock: OSAllocatedUnfairLock = OSAllocatedUnfairLock()
    fileprivate var _log: [String] = []
    fileprivate var _thread: Thread?
    fileprivate let _logSemaphore = DispatchSemaphore(value: 0)
    fileprivate let _completedSemaphore = DispatchSemaphore(value: 0)
    fileprivate var _stack: [String]? = nil
}

// MARK: - Utilities

private extension Array {
    mutating func popFirst() -> Element? {
        guard self.count > 0 else {
            return nil
        }
        return self.removeFirst()
    }
}

// MARK: - Log start and end

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB_BEGIN") @inline(never) @_optimize(none)
private func THREAD_CRUMB_BEGIN(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB_END") @inline(never) @_optimize(none)
private func THREAD_CRUMB_END(_ tc: Threadcrumb) {
    tc._stack = Thread.callStackSymbols
    tc._completedSemaphore.signal()
    tc._logSemaphore.wait()
}

// MARK: - Character implementations

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__0") @inline(never) @_optimize(none)
private func THREAD_CRUMB__0(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__1") @inline(never) @_optimize(none)
private func THREAD_CRUMB__1(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__2") @inline(never) @_optimize(none)
private func THREAD_CRUMB__2(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__3") @inline(never) @_optimize(none)
private func THREAD_CRUMB__3(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__4") @inline(never) @_optimize(none)
private func THREAD_CRUMB__4(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__5") @inline(never) @_optimize(none)
private func THREAD_CRUMB__5(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__6") @inline(never) @_optimize(none)
private func THREAD_CRUMB__6(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__7") @inline(never) @_optimize(none)
private func THREAD_CRUMB__7(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__8") @inline(never) @_optimize(none)
private func THREAD_CRUMB__8(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__9") @inline(never) @_optimize(none)
private func THREAD_CRUMB__9(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__a") @inline(never) @_optimize(none)
private func THREAD_CRUMB__a(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__b") @inline(never) @_optimize(none)
private func THREAD_CRUMB__b(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__c") @inline(never) @_optimize(none)
private func THREAD_CRUMB__c(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__d") @inline(never) @_optimize(none)
private func THREAD_CRUMB__d(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__e") @inline(never) @_optimize(none)
private func THREAD_CRUMB__e(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__f") @inline(never) @_optimize(none)
private func THREAD_CRUMB__f(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__g") @inline(never) @_optimize(none)
private func THREAD_CRUMB__g(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__h") @inline(never) @_optimize(none)
private func THREAD_CRUMB__h(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__i") @inline(never) @_optimize(none)
private func THREAD_CRUMB__i(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__j") @inline(never) @_optimize(none)
private func THREAD_CRUMB__j(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__k") @inline(never) @_optimize(none)
private func THREAD_CRUMB__k(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__l") @inline(never) @_optimize(none)
private func THREAD_CRUMB__l(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__m") @inline(never) @_optimize(none)
private func THREAD_CRUMB__m(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__n") @inline(never) @_optimize(none)
private func THREAD_CRUMB__n(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__o") @inline(never) @_optimize(none)
private func THREAD_CRUMB__o(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__p") @inline(never) @_optimize(none)
private func THREAD_CRUMB__p(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__q") @inline(never) @_optimize(none)
private func THREAD_CRUMB__q(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__r") @inline(never) @_optimize(none)
private func THREAD_CRUMB__r(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__s") @inline(never) @_optimize(none)
private func THREAD_CRUMB__s(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__t") @inline(never) @_optimize(none)
private func THREAD_CRUMB__t(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__u") @inline(never) @_optimize(none)
private func THREAD_CRUMB__u(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__v") @inline(never) @_optimize(none)
private func THREAD_CRUMB__v(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__w") @inline(never) @_optimize(none)
private func THREAD_CRUMB__w(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__x") @inline(never) @_optimize(none)
private func THREAD_CRUMB__x(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__y") @inline(never) @_optimize(none)
private func THREAD_CRUMB__y(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB__z") @inline(never) @_optimize(none)
private func THREAD_CRUMB__z(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@_silgen_name("THREAD_CRUMB___") @inline(never) @_optimize(none)
private func THREAD_CRUMB___(_ tc: Threadcrumb, _ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END(tc)
        return
    }
    fn(tc, &values)
}

// MARK: - Lookup table

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
private let _lookupTable: [String: (Threadcrumb, inout [String])->()] = [
    "0": THREAD_CRUMB__0,
    "1": THREAD_CRUMB__1,
    "2": THREAD_CRUMB__2,
    "3": THREAD_CRUMB__3,
    "4": THREAD_CRUMB__4,
    "5": THREAD_CRUMB__5,
    "6": THREAD_CRUMB__6,
    "7": THREAD_CRUMB__7,
    "8": THREAD_CRUMB__8,
    "9": THREAD_CRUMB__9,
    "a": THREAD_CRUMB__a,
    "b": THREAD_CRUMB__b,
    "c": THREAD_CRUMB__c,
    "d": THREAD_CRUMB__d,
    "e": THREAD_CRUMB__e,
    "f": THREAD_CRUMB__f,
    "g": THREAD_CRUMB__g,
    "h": THREAD_CRUMB__h,
    "i": THREAD_CRUMB__i,
    "j": THREAD_CRUMB__j,
    "k": THREAD_CRUMB__k,
    "l": THREAD_CRUMB__l,
    "m": THREAD_CRUMB__m,
    "n": THREAD_CRUMB__n,
    "o": THREAD_CRUMB__o,
    "p": THREAD_CRUMB__p,
    "q": THREAD_CRUMB__q,
    "r": THREAD_CRUMB__r,
    "s": THREAD_CRUMB__s,
    "t": THREAD_CRUMB__t,
    "u": THREAD_CRUMB__u,
    "v": THREAD_CRUMB__v,
    "w": THREAD_CRUMB__w,
    "x": THREAD_CRUMB__x,
    "y": THREAD_CRUMB__y,
    "z": THREAD_CRUMB__z,
    "_": THREAD_CRUMB___
]

// MARK: - For testing only
// Anything below here should be used for testing purposes only

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
extension Threadcrumb {
    func stringLoggingThread() -> String {
        
        let stack: [String]? = self._lock.withLock { self._stack?.map{ $0 } }
        
        guard let symbols: [String] = stack else {
            return ""
        }
        
        guard let lowIndex = symbols.lastIndex(where: { $0.contains("THREAD_CRUMB_END") } ),
              let highIndex = symbols.firstIndex(where: { $0.contains("THREAD_CRUMB_BEGIN") }) else {
            return ""
        }
        
        // _symbols_ is an array of string similar to the folowing:
        // "1   ThreadcrumbTests                    0x0000000102d754b0 THREAD_CRUMB__c + 644"
        // We want to get everything after `THREAD_CRUMB_` and before the next space.
        // In C, I'd just use backtrace and backtrace_symbols, but this will do just fine.
        let relevantSymbols = symbols[lowIndex+1..<highIndex].map { String($0) }.filter { $0.contains("THREAD_CRUMB__") }
        let extractedSymbols = relevantSymbols.filter { $0.contains("THREAD_CRUMB__") }.map {
            guard let symbolName = $0.split(separator: " THREAD_CRUMB__").last?.split(separator: " +").first else {
                return ""
            }
            return String(symbolName)
        }
        
        return extractedSymbols.reversed().joined()
    }
}
