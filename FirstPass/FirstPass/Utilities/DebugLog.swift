//
//  DebugLog.swift
//  FirstPass
//
//  Module-level shadow of Swift's debugPrint: every existing call site in
//  the app resolves to this function instead of the stdlib one, so all
//  diagnostic logging compiles away in Release builds.
//

import Foundation

@inlinable
nonisolated func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { String(reflecting: $0) }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    #endif
}
