// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI
import KeyboardShortcuts

struct HotkeyTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(String(localized: "Тип хоткею")) {
                Toggle(String(localized: "Подвійний Shift (⇧⇧)"), isOn: $settings.useDoubleShift)
                    .onChange(of: settings.useDoubleShift) {
                        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                    }
            }

            if !settings.useDoubleShift {
                Section(String(localized: "Комбінація")) {
                    KeyboardShortcuts.Recorder(String(localized: "Натисни нову комбінацію"), name: .convertText)
                        .onChange(of: KeyboardShortcuts.getShortcut(for: .convertText)) {
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                }
            }
        }
        .formStyle(.grouped)
    }
}
