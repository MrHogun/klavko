// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Foundation

struct ConversionLogEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let original: String
    let converted: String
    let mode: String // "auto" or "manual"
}
