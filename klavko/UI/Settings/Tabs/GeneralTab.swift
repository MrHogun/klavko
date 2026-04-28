// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI

struct GeneralTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(String(localized: "Конвертація")) {
                Toggle(String(localized: "Автовиправлення під час друку"), isOn: $settings.autoCorrectEnabled)

                Picker(String(localized: "Напрямок"), selection: $settings.conversionDirection) {
                    ForEach(ConversionDirection.allCases, id: \.self) { dir in
                        Text(dir.displayName).tag(dir)
                    }
                }
                .pickerStyle(.radioGroup)

                Toggle(String(localized: "Перемикати розкладку після конвертації"), isOn: $settings.switchLayoutAfterConversion)
            }

            Section(String(localized: "Система")) {
                Toggle(String(localized: "Запускати при вході в систему"), isOn: $settings.launchAtLogin)
                Toggle(String(localized: "Звуковий сигнал при конвертації"), isOn: $settings.playSounds)

                Picker(String(localized: "Мова інтерфейсу"), selection: $settings.appLanguage) {
                    Text(String(localized: "Як система")).tag("system")
                    Text(String(localized: "Українська")).tag("uk")
                    Text(String(localized: "Англійська")).tag("en")
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            HStack(spacing: 4) {
                Text("Klavko \(version)")
                Text("·")
                Link("MIT License", destination: URL(string: "https://github.com/MrHogun/klavko/blob/main/LICENSE")!)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}
