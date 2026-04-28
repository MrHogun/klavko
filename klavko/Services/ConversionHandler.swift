// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Cocoa
import ApplicationServices
import Carbon

/// Handles the actual text replacement — tries AX first, falls back to clipboard.
final class ConversionHandler {

    private let converter = LayoutConverter()

    func convert() {
        if let selectedText = getSelectedTextViaAX(), !selectedText.isEmpty {
            replaceViaAX(original: selectedText)
            return
        }
        replaceViaClipboard()
    }

    // MARK: - AX approach

    private func getSelectedTextViaAX() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedValue = focusedRef else { return nil }
        let element = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
              let text = selectedRef as? String, !text.isEmpty else { return nil }
        return text
    }

    private func replaceViaAX(original: String) {
        guard let converted = converter.convertToNextLayout(text: original), converted != original else { return }
        logAndSound(original: original, converted: converted)

        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedValue = focusedRef else { return }
        let element = unsafeBitCast(focusedValue, to: AXUIElement.self)

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, converted as CFString)
        var verifyRef: CFTypeRef?
        let verified = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &verifyRef) == .success
            && (verifyRef as? String) == converted

        if result == .success && verified {
            switchLayoutIfNeeded()
        } else {
            DispatchQueue.global(qos: .userInteractive).async {
                self.deleteAndType(count: original.count, text: converted)
                self.switchLayoutIfNeeded()
            }
        }
    }

    // MARK: - Clipboard fallback

    private func replaceViaClipboard() {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        pasteboard.clearContents()

        let changeCount = pasteboard.changeCount
        simulateKey(keyCode: 8, flags: .maskCommand)
        for _ in 0..<20 {
            usleep(50_000)
            if pasteboard.changeCount != changeCount { break }
        }

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        guard let converted = converter.convertToNextLayout(text: text), converted != text else {
            if let s = saved { pasteboard.clearContents(); pasteboard.setString(s, forType: .string) }
            return
        }

        logAndSound(original: text, converted: converted)

        DispatchQueue.global(qos: .userInteractive).async {
            self.deleteAndType(count: text.count, text: converted)
            self.switchLayoutIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let s = saved { pasteboard.clearContents(); pasteboard.setString(s, forType: .string) }
            }
        }
    }

    // MARK: - Helpers

    private func logAndSound(original: String, converted: String) {
        SettingsManager.shared.addLogEntry(original: original, converted: converted, mode: "manual")
        if SettingsManager.shared.playSounds {
            NSSound(named: .init("Tink"))?.play()
        }
    }

    func switchLayoutIfNeeded() {
        guard SettingsManager.shared.switchLayoutAfterConversion else { return }
        DispatchQueue.main.async {
            let sources = KeyboardLayoutService.enabledInputSources()
            guard sources.count >= 2 else { return }
            let current = KeyboardLayoutService.currentInputSource()
            let currentID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID)
                .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
            if let next = sources.first(where: { source in
                let id = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
                    .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
                return id != currentID
            }) {
                TISSelectInputSource(next)
            }
        }
    }

    func deleteAndType(count: Int, text: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: false)
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(3_000)
        }
        for char in text {
            let utf16 = Array(String(char).utf16)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(3_000)
        }
    }

    private func simulateKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags   = flags
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
