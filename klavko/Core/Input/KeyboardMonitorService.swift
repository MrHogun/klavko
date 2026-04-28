// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Carbon
import Cocoa

/// Monitors global keyboard input and accumulates a word buffer.
/// Calls `onWordCompleted` when a word boundary (space, enter, punctuation) is detected.
final class KeyboardMonitorService {

    var onWordCompleted: ((_ word: String) -> Void)?

    private var eventTap: CFMachPort?
    private var buffer: String = ""
    private var isPaused: Bool = false

    // Word boundary key codes
    private let boundaryKeyCodes: Set<CGKeyCode> = [
        49,  // Space
        36,  // Return
        76,  // Numpad Enter
        48,  // Tab
    ]

    // Keys that clear the buffer without triggering completion
    private let clearKeyCodes: Set<CGKeyCode> = [
        53,  // Escape
        123, 124, 125, 126, // Arrow keys
    ]

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                let service = Unmanaged<KeyboardMonitorService>.fromOpaque(refcon!).takeUnretainedValue()
                service.handleKeyDown(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("[KeyboardMonitor] Failed to create event tap — check Input Monitoring permission")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[KeyboardMonitor] Started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false; buffer = "" }

    // MARK: - Event handling

    private func handleKeyDown(event: CGEvent) {
        guard !isPaused else { return }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Ignore command/control shortcuts
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            buffer = ""
            return
        }

        // Backspace — remove last char from buffer
        if keyCode == 51 {
            if !buffer.isEmpty { buffer.removeLast() }
            return
        }

        // Arrow keys, Escape — clear buffer
        if clearKeyCodes.contains(keyCode) {
            buffer = ""
            return
        }

        // Word boundary — trigger completion
        if boundaryKeyCodes.contains(keyCode) {
            let word = buffer
            buffer = ""
            if !word.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onWordCompleted?(word)
                }
            }
            return
        }

        // Regular character — append to buffer
        if let char = characterForEvent(event) {
            buffer.append(char)
        }
    }

    private func characterForEvent(_ event: CGEvent) -> Character? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length == 1 else { return nil }
        let str = String(utf16CodeUnits: chars, count: length)
        return str.first
    }
}
