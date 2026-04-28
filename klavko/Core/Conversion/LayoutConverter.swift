// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Carbon
import Foundation

final class LayoutConverter {

    func convert(text: String, from source: KeyboardLayoutService, to target: KeyboardLayoutService) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for char in text {
            guard let (keyCode, shifted) = source.charToKeyCode[char] else {
                // Character not found in source layout — pass through unchanged
                result.append(char)
                continue
            }

            let mapKey = UInt32(keyCode) << 1 | (shifted ? 1 : 0)
            if let targetChar = target.keyCodeToChar[mapKey] {
                result.append(targetChar)
            } else {
                result.append(char)
            }
        }

        return result
    }

    /// Auto-detects which installed layout the text was typed in,
    /// converts to the next layout in the list (cycles through installed layouts).
    func convertToNextLayout(text: String) -> String? {
        let sources = KeyboardLayoutService.enabledInputSources()
        let services = sources.compactMap { KeyboardLayoutService(inputSource: $0) }
        guard services.count >= 2 else { return nil }

        // Score each layout by how many characters from text exist in it
        var bestScore = -1
        var bestIndex = 0
        for (i, service) in services.enumerated() {
            let score = text.filter { service.charToKeyCode[$0] != nil }.count
            if score > bestScore {
                bestScore = score
                bestIndex = i
            }
        }

        let targetIndex = (bestIndex + 1) % services.count
        return convert(text: text, from: services[bestIndex], to: services[targetIndex])
    }
}
