// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Carbon
import Cocoa
import KeyboardShortcuts

/// Listens for the configured hotkey and calls `onHotkey`.
/// - Double-shift mode: detected via CGEvent tap (KeyboardShortcuts doesn't support double-tap).
/// - Custom shortcut mode: delegated to KeyboardShortcuts library.
final class HotkeyService {

    var onHotkey: (() -> Void)?

    private var eventTap: CFMachPort?
    private var boxPointer: UnsafeMutableRawPointer?
    private var lastShiftTime: TimeInterval = 0
    private let doublePressInterval: TimeInterval = 0.4
    private let leftShiftKeyCode: CGKeyCode = 56
    private let rightShiftKeyCode: CGKeyCode = 60

    func start() {
        stop()
        if SettingsManager.shared.useDoubleShift {
            startDoubleShiftTap()
        } else {
            KeyboardShortcuts.onKeyDown(for: .convertText) { [weak self] in
                self?.onHotkey?()
            }
        }
    }

    func stop() {
        // Stop CGEvent tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let ptr = boxPointer {
            Unmanaged<Box<(CGEvent) -> Void>>.fromOpaque(ptr).release()
            boxPointer = nil
        }
        // Stop KeyboardShortcuts listener
        KeyboardShortcuts.disable(.convertText)
    }

    // MARK: - Double Shift (CGEvent tap)

    private func startDoubleShiftTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        createTap(mask: mask) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }
    }

    private func handleFlagsChanged(event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == leftShiftKeyCode || keyCode == rightShiftKeyCode else { return }
        guard event.flags.contains(.maskShift) else { return }

        let now = Date().timeIntervalSinceReferenceDate
        if now - lastShiftTime <= doublePressInterval {
            lastShiftTime = 0
            DispatchQueue.main.async { [weak self] in self?.onHotkey?() }
        } else {
            lastShiftTime = now
        }
    }

    // MARK: - CGEvent tap helper

    private func createTap(mask: CGEventMask, handler: @escaping (CGEvent) -> Void) {
        let box = Box(handler)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        boxPointer = ptr

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                let b = Unmanaged<Box<(CGEvent) -> Void>>.fromOpaque(refcon!).takeUnretainedValue()
                b.value(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: ptr
        )

        guard let tap else {
            Unmanaged<Box<(CGEvent) -> Void>>.fromOpaque(ptr).release()
            print("[HotkeyService] Failed to create event tap")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

private final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}
