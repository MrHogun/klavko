// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Cocoa

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt64 {
        var result: UInt64 = 0
        if contains(.command) { result |= CGEventFlags.maskCommand.rawValue }
        if contains(.option)  { result |= CGEventFlags.maskAlternate.rawValue }
        if contains(.control) { result |= CGEventFlags.maskControl.rawValue }
        if contains(.shift)   { result |= CGEventFlags.maskShift.rawValue }
        return result
    }
}
