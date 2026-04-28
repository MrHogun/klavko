// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Cocoa
import ApplicationServices
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let hotkeyService = HotkeyService()
    private let converter = LayoutConverter()
    private let keyboardMonitor = KeyboardMonitorService()
    private let autoCorrector = AutoCorrector()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        ensurePermissions {
            self.hotkeyService.onHotkey = { [weak self] in self?.performConversion() }
            self.hotkeyService.start()
            self.startAutoCorrect()
        }
    }

    // MARK: - Auto correct

    private func startAutoCorrect() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.autoCorrector.resetContext() }

        keyboardMonitor.onWordCompleted = { [weak self] word in
            guard let self, SettingsManager.shared.autoCorrectEnabled else { return }
            self.autoCorrector.check(word: word) { [weak self] original, converted in
                guard let self else { return }
                self.keyboardMonitor.pause()
                SettingsManager.shared.addLogEntry(original: original, converted: converted, mode: "auto")
                self.playSound()
                DispatchQueue.global(qos: .userInteractive).async {
                    self.deleteAndType(count: original.count + 1, text: converted + " ")
                    self.switchLayoutIfNeeded()
                    DispatchQueue.main.async { self.keyboardMonitor.resume() }
                }
            }
        }
        keyboardMonitor.start()
    }

    // MARK: - Permissions

    private func ensurePermissions(completion: @escaping () -> Void) {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            openAccessibilitySettings()
            pollAccessibility(completion: completion)
            return
        }
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            openInputMonitoringSettings()
            pollInputMonitoring(completion: completion)
            return
        }
        completion()
    }

    private func pollAccessibility(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            while !AXIsProcessTrusted() { Thread.sleep(forTimeInterval: 1.0) }
            DispatchQueue.main.async { self.ensurePermissions(completion: completion) }
        }
    }

    private func pollInputMonitoring(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            while !CGPreflightListenEventAccess() { Thread.sleep(forTimeInterval: 1.0) }
            DispatchQueue.main.async { self.ensurePermissions(completion: completion) }
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSImage(named: "MenuBarIcon") {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            statusItem.button?.image = icon
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Klavko")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Klavko", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Конвертувати виділений текст"), action: #selector(performConversion), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Налаштування..."), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Вийти"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Settings window

    @objc private func openSettings() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView()
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = String(localized: "Klavko — Налаштування")
        win.styleMask = [.titled, .closable]
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }

    // MARK: - Manual conversion

    @objc func performConversion() {
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
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return nil }
        var selectedText: CFTypeRef?
        guard let axElement = element as? AXUIElement,
              AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success,
              let text = selectedText as? String, !text.isEmpty else { return nil }
        return text
    }

    private func replaceViaAX(original: String) {
        guard let converted = converter.convertToNextLayout(text: original), converted != original else { return }
        SettingsManager.shared.addLogEntry(original: original, converted: converted, mode: "manual")
        playSound()

        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return }

        guard let axElement = element as? AXUIElement else { return }
        let result = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, converted as CFString)
        var verifyRef: CFTypeRef?
        let verifyOk = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &verifyRef) == .success
        let actualText = verifyOk ? (verifyRef as? String) : nil

        if result == .success && actualText == converted {
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

        SettingsManager.shared.addLogEntry(original: text, converted: converted, mode: "manual")
        playSound()

        DispatchQueue.global(qos: .userInteractive).async {
            self.deleteAndType(count: text.count, text: converted)
            self.switchLayoutIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let s = saved { pasteboard.clearContents(); pasteboard.setString(s, forType: .string) }
            }
        }
    }

    // MARK: - Layout switch

    private func switchLayoutIfNeeded() {
        guard SettingsManager.shared.switchLayoutAfterConversion else { return }
        DispatchQueue.main.async {
            let sources = KeyboardLayoutService.enabledInputSources()
            guard sources.count >= 2 else { return }
            let current = KeyboardLayoutService.currentInputSource()
            let currentID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID)
                .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
            // Switch to next source
            if let next = sources.first(where: { source in
                let id = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
                    .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
                return id != currentID
            }) {
                TISSelectInputSource(next)
            }
        }
    }

    // MARK: - Sound feedback

    private func playSound() {
        guard SettingsManager.shared.playSounds else { return }
        NSSound(named: .init("Tink"))?.play()
    }

    // MARK: - Delete + type

    private func deleteAndType(count: Int, text: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        for _ in 0 ..< count {
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

    // MARK: - Key simulation

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
