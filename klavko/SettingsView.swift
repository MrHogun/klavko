// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button {
                        selectedTab = index
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.title)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == index ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Divider().padding(.top, 4)

            switch selectedTab {
            case 0: GeneralTab(settings: settings)
            case 1: HotkeyTab(settings: settings)
            case 2: LogTab(settings: settings)
            default: EmptyView()
            }
        }
        .frame(width: 520, height: 480)
    }

    private var tabs: [(title: String, icon: String)] {
        [
            (String(localized: "Загальне"), "gear"),
            (String(localized: "Хоткей"), "command"),
            (String(localized: "Лог"), "list.bullet.rectangle"),
        ]
    }
}

// MARK: - General Tab

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

// MARK: - Hotkey Tab

struct HotkeyTab: View {
    @ObservedObject var settings: SettingsManager
    @State private var isRecording = false

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

struct HotkeyRecorderRow: View {
    @ObservedObject var settings: SettingsManager
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(String(localized: "Натисни нову комбінацію"))
            Spacer()
            Button(isRecording ? String(localized: "Записую...") : String(localized: "Змінити")) {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .red : .accentColor)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }
            settings.hotkeyKeyCode = event.keyCode
            settings.hotkeyModifiers = mods.carbonFlags
            stopRecording()
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Log Tab

struct LogTab: View {
    @ObservedObject var settings: SettingsManager

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if settings.conversionLog.isEmpty {
                Spacer()
                Text(String(localized: "Лог порожній"))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(settings.conversionLog) { entry in
                    HStack(spacing: 12) {
                        Text(dateFormatter.string(from: entry.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)

                        Text(entry.original)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.red.opacity(0.8))

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(entry.converted)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.8))

                        Spacer()

                        Text(entry.mode == "auto" ? String(localized: "авто") : String(localized: "ручне"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(entry.mode == "auto" ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            HStack {
                Text(String(format: String(localized: "%d записів"), settings.conversionLog.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "Очистити")) { settings.clearLog() }
                    .buttonStyle(.bordered)
                    .disabled(settings.conversionLog.isEmpty)
            }
            .padding(12)
        }
    }
}

// MARK: - Extensions

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt64 {
        var result: UInt64 = 0
        if contains(.command) { result |= CGEventFlags.maskCommand.rawValue }
        if contains(.option)  { result |= CGEventFlags.maskAlternate.rawValue }
        if contains(.control) { result |= CGEventFlags.maskControl.rawValue }
        if contains(.shift)   { result |= CGEventFlags.maskShift.rawValue }
        return result
    }
}

extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("klavko.hotkeySettingsChanged")
}
