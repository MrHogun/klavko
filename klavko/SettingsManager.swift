// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Foundation
import Carbon
import Combine
import ServiceManagement

enum ConversionDirection: Int, CaseIterable, Codable {
    case both = 0       // EN↔UA (обидві сторони)
    case toUkrainian = 1 // тільки EN→UA
    case toEnglish = 2   // тільки UA→EN

    var displayName: String {
        switch self {
        case .both: return String(localized: "Обидві сторони (EN↔UA)")
        case .toUkrainian: return String(localized: "Тільки EN → UA")
        case .toEnglish: return String(localized: "Тільки UA → EN")
        }
    }
}

struct ConversionLogEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let original: String
    let converted: String
    let mode: String // "auto" or "manual"
}

final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let useDoubleShift = "useDoubleShift"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let conversionDirection = "conversionDirection"
        static let autoCorrectEnabled = "autoCorrectEnabled"
        static let switchLayoutAfterConversion = "switchLayoutAfterConversion"
        static let launchAtLogin = "launchAtLogin"
        static let playSounds = "playSounds"
        static let conversionLog = "conversionLog"
        static let maxLogEntries = "maxLogEntries"
        static let appLanguage = "appLanguage"
    }

    // MARK: - Settings

    @Published var useDoubleShift: Bool {
        didSet { defaults.set(useDoubleShift, forKey: Keys.useDoubleShift) }
    }

    @Published var hotkeyKeyCode: UInt16 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode) }
    }

    @Published var hotkeyModifiers: UInt64 {
        didSet { defaults.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers) }
    }

    @Published var conversionDirection: ConversionDirection {
        didSet { defaults.set(conversionDirection.rawValue, forKey: Keys.conversionDirection) }
    }

    @Published var autoCorrectEnabled: Bool {
        didSet { defaults.set(autoCorrectEnabled, forKey: Keys.autoCorrectEnabled) }
    }

    @Published var switchLayoutAfterConversion: Bool {
        didSet { defaults.set(switchLayoutAfterConversion, forKey: Keys.switchLayoutAfterConversion) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: Keys.playSounds) }
    }

    /// "system" | "uk" | "en"
    @Published var appLanguage: String {
        didSet {
            defaults.set(appLanguage, forKey: Keys.appLanguage)
            applyLanguage(appLanguage)
        }
    }

    @Published var conversionLog: [ConversionLogEntry] {
        didSet { saveLog() }
    }

    var maxLogEntries: Int {
        get { defaults.integer(forKey: Keys.maxLogEntries) == 0 ? 100 : defaults.integer(forKey: Keys.maxLogEntries) }
        set { defaults.set(newValue, forKey: Keys.maxLogEntries) }
    }

    // MARK: - Init

    private init() {
        useDoubleShift = defaults.object(forKey: Keys.useDoubleShift) as? Bool ?? true
        hotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode) == 0 ? 49 : defaults.integer(forKey: Keys.hotkeyKeyCode))
        hotkeyModifiers = defaults.object(forKey: Keys.hotkeyModifiers) as? UInt64 ?? (CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue)
        conversionDirection = ConversionDirection(rawValue: defaults.integer(forKey: Keys.conversionDirection)) ?? .both
        autoCorrectEnabled = defaults.object(forKey: Keys.autoCorrectEnabled) as? Bool ?? true
        switchLayoutAfterConversion = defaults.object(forKey: Keys.switchLayoutAfterConversion) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        playSounds = defaults.object(forKey: Keys.playSounds) as? Bool ?? false
        appLanguage = defaults.string(forKey: Keys.appLanguage) ?? "system"
        conversionLog = SettingsManager.loadLog()
        applyLanguage(appLanguage)
    }

    // MARK: - Hotkey description

    var hotkeyDescription: String {
        if useDoubleShift { return "⇧⇧" }
        var parts: [String] = []
        let mods = CGEventFlags(rawValue: hotkeyModifiers)
        if mods.contains(.maskControl) { parts.append("⌃") }
        if mods.contains(.maskAlternate) { parts.append("⌥") }
        if mods.contains(.maskShift) { parts.append("⇧") }
        if mods.contains(.maskCommand) { parts.append("⌘") }
        if let char = keyCodeToString(hotkeyKeyCode) { parts.append(char) }
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫",
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
            4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M",
            45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S",
            17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z"
        ]
        return map[keyCode]
    }

    // MARK: - Log

    func addLogEntry(original: String, converted: String, mode: String) {
        let entry = ConversionLogEntry(id: UUID(), date: Date(), original: original, converted: converted, mode: mode)
        var log = conversionLog
        log.insert(entry, at: 0)
        if log.count > maxLogEntries { log = Array(log.prefix(maxLogEntries)) }
        conversionLog = log
    }

    func clearLog() {
        conversionLog = []
    }

    private func saveLog() {
        if let data = try? JSONEncoder().encode(conversionLog) {
            defaults.set(data, forKey: Keys.conversionLog)
        }
    }

    private static func loadLog() -> [ConversionLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: Keys.conversionLog),
              let entries = try? JSONDecoder().decode([ConversionLogEntry].self, from: data) else {
            return []
        }
        return entries
    }

    // MARK: - Language

    private func applyLanguage(_ lang: String) {
        if lang == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        }
    }

    // MARK: - Launch at login

    private func applyLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[SettingsManager] Launch at login error: \(error)")
            }
        }
    }
}
