//
//  KeyboardLayout.swift
//  FirstPass
//
//  Layout-independent key matching helpers.
//
//  Why this exists: matching shortcuts on hardware keyCodes breaks on
//  non-QWERTY layouts (e.g. AZERTY swaps A/Q), and macOS remaps menu key
//  equivalents by physical position on those layouts — so an unhandled
//  "Cmd+A" can end up triggering the menu's Cmd+Q and quit the app.
//  Letters must therefore be matched on the typed character, and the
//  digit row on physical keyCodes (on AZERTY the digit row types symbols
//  unless Shift is held, but users expect the unshifted key to rate).
//

import AppKit

enum KeyboardLayout {

    /// Physical ANSI number-row keyCodes (layout-independent positions).
    private static let numberRowKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9, 29: 0
    ]

    /// Numeric keypad keyCodes.
    private static let keypadKeyCodes: [UInt16: Int] = [
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5,
        88: 6, 89: 7, 91: 8, 92: 9, 82: 0
    ]

    /// Returns the digit (0-9) for a key event, regardless of keyboard layout.
    /// Checks the physical number row and keypad first, then falls back to the
    /// typed character for any other layout.
    static func digit(from event: NSEvent) -> Int? {
        if let d = numberRowKeyCodes[event.keyCode] ?? keypadKeyCodes[event.keyCode] {
            return d
        }
        if let chars = event.charactersIgnoringModifiers, chars.count == 1, let d = Int(chars) {
            return d
        }
        return nil
    }

    /// Returns the typed character, lowercased, when the event is a single character.
    static func lowercasedChar(from event: NSEvent) -> String? {
        guard let chars = event.charactersIgnoringModifiers, chars.count == 1 else { return nil }
        return chars.lowercased()
    }
}
