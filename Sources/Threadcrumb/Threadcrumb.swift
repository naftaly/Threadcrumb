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
        
        self._thread = Thread { [weak self] in
            guard let self = self else {
                return
            }
            let thread = Thread.current
            while(thread.isExecuting && !thread.isCancelled) {
                self._lock.lock()
                var values: [String] = self._log
                self._lock.unlock()
                
                // there are about 4 frames per characters (due to Swift !thunks!),
                // then 10 more for the prefix/postfix.
                let prevSize = thread.stackSize
                let newSize = max( Int(PTHREAD_STACK_MIN), (values.count * 4) + 10 )
                if newSize > prevSize {
                    thread.stackSize = newSize
                }
                THREAD_CRUMB_BEGIN(&values)
            }
        }
        self._thread?.name = self.identifier
        self._thread?.tc_Semaphore = DispatchSemaphore(value: 0)
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
        _log = validatedCharacters
        _lock.unlock()
        
        // signal the thread.
        // by doing so, the thread will begin iterating over `_log`
        // then wait again. this leaves the thread with a
        // stack that describes `_log`.
        self._thread?.tc_Semaphore?.signal()
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
    private let _lock: OSAllocatedUnfairLock = OSAllocatedUnfairLock()
    private var _log: [String] = []
    private var _thread: Thread?
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

private let ThreadcrumbDictionarySemaphoreKey = "threadcrumb.semaphore.key"
private let ThreadcrumbDictionaryStackKey = "threadcrumb.stack.key"

private extension Thread {
    var tc_Semaphore: DispatchSemaphore? {
        get {
            return threadDictionary[ThreadcrumbDictionarySemaphoreKey] as? DispatchSemaphore
        }
        set {
            threadDictionary[ThreadcrumbDictionarySemaphoreKey] = newValue
        }
    }
    
    var tc_Stack: [String]? {
        get {
            return threadDictionary[ThreadcrumbDictionaryStackKey] as? [String]
        }
        set {
            threadDictionary[ThreadcrumbDictionaryStackKey] = newValue
        }
    }
}

// MARK: - Log start and end

@_silgen_name("THREAD_CRUMB_BEGIN") @inline(never) @_optimize(none)
private func THREAD_CRUMB_BEGIN(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB_END") @inline(never) @_optimize(none)
private func THREAD_CRUMB_END() {
    Thread.current.tc_Stack = Thread.callStackSymbols
    Thread.current.tc_Semaphore?.wait()
    Thread.current.tc_Stack = nil
}

// MARK: - Character implementations

@_silgen_name("THREAD_CRUMB__0") @inline(never) @_optimize(none)
private func THREAD_CRUMB__0(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__1") @inline(never) @_optimize(none)
private func THREAD_CRUMB__1(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__2") @inline(never) @_optimize(none)
private func THREAD_CRUMB__2(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__3") @inline(never) @_optimize(none)
private func THREAD_CRUMB__3(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__4") @inline(never) @_optimize(none)
private func THREAD_CRUMB__4(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__5") @inline(never) @_optimize(none)
private func THREAD_CRUMB__5(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__6") @inline(never) @_optimize(none)
private func THREAD_CRUMB__6(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__7") @inline(never) @_optimize(none)
private func THREAD_CRUMB__7(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__8") @inline(never) @_optimize(none)
private func THREAD_CRUMB__8(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__9") @inline(never) @_optimize(none)
private func THREAD_CRUMB__9(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__a") @inline(never) @_optimize(none)
private func THREAD_CRUMB__a(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__b") @inline(never) @_optimize(none)
private func THREAD_CRUMB__b(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__c") @inline(never) @_optimize(none)
private func THREAD_CRUMB__c(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__d") @inline(never) @_optimize(none)
private func THREAD_CRUMB__d(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__e") @inline(never) @_optimize(none)
private func THREAD_CRUMB__e(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__f") @inline(never) @_optimize(none)
private func THREAD_CRUMB__f(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__g") @inline(never) @_optimize(none)
private func THREAD_CRUMB__g(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__h") @inline(never) @_optimize(none)
private func THREAD_CRUMB__h(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__i") @inline(never) @_optimize(none)
private func THREAD_CRUMB__i(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__j") @inline(never) @_optimize(none)
private func THREAD_CRUMB__j(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__k") @inline(never) @_optimize(none)
private func THREAD_CRUMB__k(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__l") @inline(never) @_optimize(none)
private func THREAD_CRUMB__l(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__m") @inline(never) @_optimize(none)
private func THREAD_CRUMB__m(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__n") @inline(never) @_optimize(none)
private func THREAD_CRUMB__n(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__o") @inline(never) @_optimize(none)
private func THREAD_CRUMB__o(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__p") @inline(never) @_optimize(none)
private func THREAD_CRUMB__p(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__q") @inline(never) @_optimize(none)
private func THREAD_CRUMB__q(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__r") @inline(never) @_optimize(none)
private func THREAD_CRUMB__r(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__s") @inline(never) @_optimize(none)
private func THREAD_CRUMB__s(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__t") @inline(never) @_optimize(none)
private func THREAD_CRUMB__t(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__u") @inline(never) @_optimize(none)
private func THREAD_CRUMB__u(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__v") @inline(never) @_optimize(none)
private func THREAD_CRUMB__v(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__w") @inline(never) @_optimize(none)
private func THREAD_CRUMB__w(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__x") @inline(never) @_optimize(none)
private func THREAD_CRUMB__x(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__y") @inline(never) @_optimize(none)
private func THREAD_CRUMB__y(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

@_silgen_name("THREAD_CRUMB__z") @inline(never) @_optimize(none)
private func THREAD_CRUMB__z(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}


@_silgen_name("THREAD_CRUMB___") @inline(never) @_optimize(none)
private func THREAD_CRUMB___(_ values: inout [String]) {
    guard let char = values.popFirst(), let fn = _lookupTable[char] else {
        THREAD_CRUMB_END()
        return
    }
    fn(&values)
}

// MARK: - Lookup table

private let _lookupTable: [String: (inout [String])->()] = [
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
        
        // in case we just called `.log`, we need to give the 
        // thread a second to receive the signal and complete
        // the frame calls. We could/should use something to wait/signal
        // here instead but this is simply for testing and will do the trick.
        Thread.sleep(forTimeInterval: 1)
        
        guard let symbols: [String] = self._thread?.tc_Stack else {
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
