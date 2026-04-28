// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI

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
