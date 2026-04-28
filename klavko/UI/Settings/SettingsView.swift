// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
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
