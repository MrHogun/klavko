// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI

struct HotkeyTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(String(localized: "Поточний хоткей")) {
                HStack {
                    Text(String(localized: "Комбінація"))
                    Spacer()
                    Text(settings.hotkeyDescription)
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section(String(localized: "Тип хоткею")) {
                Toggle(String(localized: "Подвійний Shift (⇧⇧)"), isOn: $settings.useDoubleShift)
                    .onChange(of: settings.useDoubleShift) {
                        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                    }

                if !settings.useDoubleShift {
                    HotkeyRecorderRow(settings: settings)
                }
            }
        }
        .formStyle(.grouped)
    }
}
