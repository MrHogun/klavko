// Copyright (c) 2026 MrHogun. Licensed under the MIT License.

import Cocoa
import ApplicationServices

/// Ensures Accessibility and Input Monitoring permissions are granted.
/// Polls in the background and calls `completion` once both are available.
final class PermissionsService {

    func ensurePermissions(completion: @escaping () -> Void) {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            openAccessibilitySettings()
            pollAccessibility(completion: completion)
            return
        }
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            openInputMonitoringSettings()
            pollInputMonitoring(completion: completion)
            return
        }
        completion()
    }

    // MARK: - Polling

    private func pollAccessibility(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            while !AXIsProcessTrusted() { Thread.sleep(forTimeInterval: 1.0) }
            DispatchQueue.main.async { self.ensurePermissions(completion: completion) }
        }
    }

    private func pollInputMonitoring(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            while !CGPreflightListenEventAccess() { Thread.sleep(forTimeInterval: 1.0) }
            DispatchQueue.main.async { self.ensurePermissions(completion: completion) }
        }
    }

    // MARK: - Deep links

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
