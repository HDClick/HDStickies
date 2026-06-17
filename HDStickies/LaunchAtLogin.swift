// ============================================================
// LaunchAtLogin.swift
// ============================================================
// Handles Launch at Login using ServiceManagement framework.
// This is the modern macOS 13+ approach — no helper app needed.
// ============================================================

import Foundation
import ServiceManagement

struct LaunchAtLogin {

    // Called on app launch to sync the toggle state
    static func configure() {
        // Nothing needed on launch — SMAppService handles it
    }

    // Enable or disable launch at login
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("✅ Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("✅ Launch at login disabled")
            }
        } catch {
            print("❌ Launch at login error: \(error.localizedDescription)")
        }
    }

    // Check current state
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
