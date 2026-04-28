// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Foundation

enum ConversionDirection: Int, CaseIterable, Codable {
    case both = 0
    case toUkrainian = 1
    case toEnglish = 2

    var displayName: String {
        switch self {
        case .both: return String(localized: "Обидві сторони (EN↔UA)")
        case .toUkrainian: return String(localized: "Тільки EN → UA")
        case .toEnglish: return String(localized: "Тільки UA → EN")
        }
    }
}
