// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI

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
                    LogEntryRow(entry: entry, dateFormatter: dateFormatter)
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

private struct LogEntryRow: View {
    let entry: ConversionLogEntry
    let dateFormatter: DateFormatter

    var body: some View {
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
