// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import AppKit

/// Checks whether a word exists in a given language using the system spell checker.
/// Uses NSSpellChecker — offline, uses macOS built-in dictionaries.
final class WordChecker {

    static let shared = WordChecker()
    private let checker = NSSpellChecker.shared

    private init() {}

    // Known short words per language (spellchecker is unreliable for 1-2 char words)
    private static let shortWords: [String: Set<String>] = [
        "en": ["a", "i", "an", "am", "is", "it", "to", "of", "in", "on", "at", "as", "by",
               "we", "he", "me", "my", "do", "if", "or", "no", "so", "us", "be", "go", "up",
               "ok", "hi", "oh", "ah", "id", "vs", "eg", "ie"],
        "uk": ["в", "у", "і", "й", "та", "не", "на", "до", "за", "з", "із", "це", "я", "ми",
               "ти", "ви", "як", "чи", "що", "де", "бо", "то", "ті", "її", "їх", "ще", "ні",
               "є", "б", "ж", "о", "а", "й", "чи", "ж", "би", "хі", "ну", "ай", "ой",
               "ej", "аж", "бо", "ба", "чи", "же", "мо", "по"],
    ]

    private static let cyrillicChars: CharacterSet = {
        var cs = CharacterSet()
        cs.insert(charactersIn: Unicode.Scalar(0x0400)!...Unicode.Scalar(0x052F)!)
        return cs
    }()
    private static let latinChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let cyrillicLanguages = Set(["uk", "ru", "be", "bg", "sr", "mk"])

    /// Returns true if the word is recognized as valid in the given language.
    /// languageCode examples: "uk", "en", "uk-UA", "en-US"
    func isValid(word: String, language: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { return false }

        let langBase = language.components(separatedBy: "-").first ?? language
        let isCyrillicLang = WordChecker.cyrillicLanguages.contains(langBase)

        // Check script matches language — cyrillic words can't be valid English and vice versa
        let hasCyrillic = trimmed.unicodeScalars.contains { WordChecker.cyrillicChars.contains($0) }
        let hasLatin = trimmed.unicodeScalars.contains { WordChecker.latinChars.contains($0) }

        if isCyrillicLang && !hasCyrillic { return false }
        if !isCyrillicLang && !hasLatin { return false }
        if hasCyrillic && hasLatin { return false } // mixed script — invalid

        // For short words use explicit list — spellchecker has too many false positives
        if trimmed.count <= 2 {
            let langBase = language.components(separatedBy: "-").first ?? language
            return WordChecker.shortWords[langBase]?.contains(trimmed) ?? false
        }

        let range = checker.checkSpelling(
            of: trimmed,
            startingAt: 0,
            language: language,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )

        return range.location == NSNotFound
    }

    /// Detects which language the word likely belongs to from the candidate list.
    /// Returns the language code with the highest confidence, or nil if none match.
    func detectLanguage(word: String, candidates: [String]) -> String? {
        for lang in candidates {
            if isValid(word: word, language: lang) {
                return lang
            }
        }
        return nil
    }
}
