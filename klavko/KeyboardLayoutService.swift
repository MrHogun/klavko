// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Carbon
import Foundation

/// Builds a bidirectional map between characters and key codes for a given keyboard layout.
/// Scans both unshifted and shifted states so symbols like `&`, `?`, `.` are covered.
final class KeyboardLayoutService {

    /// Maps a character to the (keyCode, shiftModifier) that produces it in this layout.
    let charToKeyCode: [Character: (keyCode: CGKeyCode, shifted: Bool)]

    /// Maps (keyCode, shifted) to the character it produces in this layout.
    let keyCodeToChar: [UInt32: Character] // key = keyCode << 1 | (shifted ? 1 : 0)

    init?(inputSource: TISInputSource) {
        guard let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else { return nil }

        let cfData = unsafeBitCast(layoutDataRef, to: CFData.self)
        guard let rawPtr = CFDataGetBytePtr(cfData) else { return nil }
        let layoutDataPtr = UnsafeRawPointer(rawPtr).assumingMemoryBound(to: UCKeyboardLayout.self)

        var charToCode: [Character: (CGKeyCode, Bool)] = [:]
        var codeToChar: [UInt32: Character] = [:]

        let kbdType = UInt32(LMGetKbdType())

        // Scan unshifted (0) and shifted (shiftKey >> 8 = 2) modifier states
        let modifierStates: [(UInt32, Bool)] = [(0, false), (UInt32(shiftKey) >> 8, true)]

        for keyCode in 0 ..< 128 as Range<CGKeyCode> {
            for (modifiers, shifted) in modifierStates {
                var deadKeyState: UInt32 = 0
                var unicodeString = [UniChar](repeating: 0, count: 4)
                var actualLength = 0

                let status = UCKeyTranslate(
                    layoutDataPtr,
                    keyCode,
                    UInt16(kUCKeyActionDown),
                    modifiers,
                    kbdType,
                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    4,
                    &actualLength,
                    &unicodeString
                )

                guard status == noErr, actualLength == 1 else { continue }

                let str = String(utf16CodeUnits: unicodeString, count: actualLength)
                guard let ch = str.first,
                      ch.isLetter || ch.isNumber || ch.isPunctuation || ch.isSymbol else { continue }

                let mapKey = UInt32(keyCode) << 1 | (shifted ? 1 : 0)

                if codeToChar[mapKey] == nil {
                    codeToChar[mapKey] = ch
                }
                if charToCode[ch] == nil {
                    charToCode[ch] = (keyCode, shifted)
                }
            }
        }

        self.charToKeyCode = charToCode
        self.keyCodeToChar = codeToChar
    }

    // MARK: - Static helpers

    static func enabledInputSources() -> [TISInputSource] {
        let filter: [String: Any] = [
            kTISPropertyInputSourceIsEnabled as String: true,
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() else {
            return []
        }
        let count = CFArrayGetCount(list)
        return (0 ..< count).compactMap { i in
            let ptr = CFArrayGetValueAtIndex(list, i)
            return Unmanaged<TISInputSource>.fromOpaque(ptr!).takeUnretainedValue()
        }
    }

    static func currentInputSource() -> TISInputSource {
        TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
    }
}
