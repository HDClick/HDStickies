// ============================================================
// HDStickiesApp.swift
// ============================================================
// Entry point for HDStickies.
// Launches silently into the menu bar — no window on startup.
// ============================================================

import SwiftUI

@main
struct HDStickiesApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// ============================================================
// AppDelegate
// ============================================================

class AppDelegate: NSObject, NSApplicationDelegate {

    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — menu bar utility only
        NSApp.setActivationPolicy(.accessory)

        // Launch at login if enabled in settings
        LaunchAtLogin.configure()

        // Start menu bar icon + global hotkey
        menuBarManager = MenuBarManager()
        menuBarManager?.setup()

        // Restore any notes that were open when app last quit
        NoteWindowManager.shared.restoreNotes()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save open note states before quitting
        NoteWindowManager.shared.saveNoteStates()
    }
}
