// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let hotkeyService = HotkeyService()
    private let keyboardMonitor = KeyboardMonitorService()
    private let autoCorrector = AutoCorrector()
    private let conversionHandler = ConversionHandler()
    private let permissions = PermissionsService()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        permissions.ensurePermissions {
            self.hotkeyService.onHotkey = { [weak self] in self?.conversionHandler.convert() }
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
                if SettingsManager.shared.playSounds { NSSound(named: .init("Tink"))?.play() }
                DispatchQueue.global(qos: .userInteractive).async {
                    self.conversionHandler.deleteAndType(count: original.count + 1, text: converted + " ")
                    self.conversionHandler.switchLayoutIfNeeded()
                    DispatchQueue.main.async { self.keyboardMonitor.resume() }
                }
            }
        }
        keyboardMonitor.start()
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
        let win = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        win.title = String(localized: "Klavko — Налаштування")
        win.styleMask = [.titled, .closable]
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }

    @objc private func performConversion() {
        conversionHandler.convert()
    }
}
