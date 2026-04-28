// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

//
//  klavkoApp.swift
//  klavko
//
//  Created by Petro Halkevych on 28.04.2026.
//

import SwiftUI

@main
struct klavkoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — menu bar only app
        Settings { EmptyView() }
    }
}
