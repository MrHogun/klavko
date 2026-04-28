// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Cocoa
import Carbon

/// Automatically detects and corrects words typed in the wrong keyboard layout.
/// Decision is based purely on script analysis (Latin↔Cyrillic switch).
/// This is the same approach used by LangSwitcher and SwitchFix.
final class AutoCorrector {

    private let converter = LayoutConverter()

    func check(word: String, onCorrect: @escaping (_ original: String, _ converted: String) -> Void) {
        guard word.count >= 1 else { return }

        let sources = KeyboardLayoutService.enabledInputSources()
        let pairs: [(KeyboardLayoutService, String)] = sources.compactMap { source in
            guard let service = KeyboardLayoutService(inputSource: source) else { return nil }
            guard let langRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return nil }
            let langs = unsafeBitCast(langRef, to: CFArray.self) as? [String]
            guard let lang = langs?.first else { return nil }
            return (service, lang)
        }
        guard pairs.count >= 2 else { return }

        let direction = SettingsManager.shared.conversionDirection

        for (i, (sourceService, sourceLang)) in pairs.enumerated() {
            let coverage = word.filter { sourceService.charToKeyCode[$0] != nil }.count
            guard coverage >= max(1, word.count / 2) else { continue }

            for (j, (targetService, _)) in pairs.enumerated() {
                guard i != j else { continue }

                // Apply direction filter
                let sourceIsCyrillic = hasCyrillic(sourceLang)
                switch direction {
                case .toUkrainian where sourceIsCyrillic: continue  // skip Cyrillic→Latin
                case .toEnglish where !sourceIsCyrillic: continue   // skip Latin→Cyrillic
                case .both: break
                default: break
                }

                let converted = converter.convert(text: word, from: sourceService, to: targetService)
                guard converted != word else { continue }

                guard isScriptSwitch(from: word, to: converted) else { continue }

                let wordLetters = String(word.filter { $0.isLetter })
                if WordChecker.shared.isValid(word: wordLetters, language: sourceLang) {
                    print("[AutoCorrector] '\(word)' is valid in '\(sourceLang)', skipping")
                    continue
                }

                onCorrect(word, converted)
                return
            }
        }
    }

    func resetContext() {}

    // MARK: - Script analysis

    /// Returns true only if text switches between Latin and Cyrillic scripts.
    /// Latin→Cyrillic: "ghbdsn" → "привіт" ✓
    /// Cyrillic→Latin: "руддщ" → "hello" ✓
    /// Same script: no conversion
    private func hasCyrillic(_ lang: String) -> Bool {
        let cyrillic = Set(["uk", "ru", "be", "bg", "sr", "mk"])
        return cyrillic.contains(lang.components(separatedBy: "-").first ?? lang)
    }

    private func isScriptSwitch(from original: String, to converted: String) -> Bool {
        let letters = original.filter { $0.isLetter }
        let convertedLetters = converted.filter { $0.isLetter }
        guard !letters.isEmpty, !convertedLetters.isEmpty else { return false }

        let origCyrillic = letters.unicodeScalars.contains { $0.value >= 0x0400 && $0.value <= 0x052F }
        let origLatin = letters.unicodeScalars.contains { $0.value >= 0x0041 && $0.value <= 0x007A }
        let convCyrillic = convertedLetters.unicodeScalars.contains { $0.value >= 0x0400 && $0.value <= 0x052F }
        let convLatin = convertedLetters.unicodeScalars.contains { $0.value >= 0x0041 && $0.value <= 0x007A }

        // Must be purely one script switching to purely the other
        return (origLatin && !origCyrillic && convCyrillic && !convLatin) ||
               (origCyrillic && !origLatin && convLatin && !convCyrillic)
    }
}
