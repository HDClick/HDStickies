// ============================================================
// SettingsView.swift
// ============================================================
// A clean settings window opened from the menu bar icon.
// Sections:
// - General: Launch at Login, Default note colour
// - Storage: Default save folder
// - Appearance: Default font, font size
// - About: Version info
// ============================================================

import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {

    // Launch at Login toggle
    @AppStorage("LaunchAtLogin") private var launchAtLogin = false
    @AppStorage("LiquidGlass") private var liquidGlass = false

    // Default note colour
    @AppStorage("DefaultNoteColor") private var defaultColorName = "red"

    // Default font
    @AppStorage("DefaultFontName") private var defaultFontName = "System"
    @AppStorage("DefaultFontSize") private var defaultFontSize = 13.0

    // Current save folder display
    @State private var saveFolderDisplay: String = NoteWindowManager.shared.saveFolder?.path ?? "Not set"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                Text("HDStickies Settings")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.bottom, 20)

            // ---- GENERAL ----
            sectionHeader("General")

            settingsRow {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { value in
                        LaunchAtLogin.setEnabled(value)
                    }
            }

            if #available(macOS 26.0, *) {
                settingsRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Liquid Glass Notes", isOn: $liquidGlass)
                            .toggleStyle(.switch)
                        Text("Applies Apple\'s Liquid Glass effect to floating notes")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            settingsRow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Note Colour")
                        Spacer()
                        HStack(spacing: 6) {
                            // Colour circles for each named colour
                            ForEach(NoteColor.allCases) { color in
                                Button(action: { defaultColorName = color.rawValue }) {
                                    Circle()
                                        .fill(color.background)
                                        .frame(width: 18, height: 18)
                                        .overlay(Circle().stroke(
                                            defaultColorName == color.rawValue ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        ))
                                }
                                .buttonStyle(.plain)
                                .help(color.displayName)
                            }

                            // Random option — rainbow gradient circle
                            Button(action: { defaultColorName = "random" }) {
                                Circle()
                                    .fill(AngularGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                        center: .center
                                    ))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(
                                        defaultColorName == "random" ? Color.primary : Color.clear,
                                        lineWidth: 2
                                    ))
                            }
                            .buttonStyle(.plain)
                            .help("Random — picks a different colour each time")
                        }
                    }
                    // Show hint when random is selected
                    if defaultColorName == "random" {
                        Text("🎲 Each new note gets a random colour")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().padding(.vertical, 12)

            // ---- STORAGE ----
            sectionHeader("Storage")

            settingsRow {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Save Folder")
                        Spacer()
                        Button("Choose…") {
                            NoteWindowManager.shared.chooseSaveFolder { url in
                                saveFolderDisplay = url?.path ?? "Not set"
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    Text(saveFolderDisplay)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Divider().padding(.vertical, 12)

            // ---- APPEARANCE ----
            sectionHeader("Appearance")

            settingsRow {
                HStack {
                    Text("Default Font Size")
                    Spacer()
                    Button(action: { if defaultFontSize > 9 { defaultFontSize -= 1 }}) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    Text("\(Int(defaultFontSize))pt")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 40)
                    Button(action: { if defaultFontSize < 32 { defaultFontSize += 1 }}) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            settingsRow {
                HStack {
                    Text("Default Font")
                    Spacer()
                    Text(defaultFontName == "System" ? "System Default" : defaultFontName)
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Button("Change…") {
                        showFontPicker()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider().padding(.vertical, 12)

            // ---- HOTKEYS ----
            sectionHeader("Global Hotkeys")

            settingsRow {
                VStack(spacing: 8) {
                    HotkeyRecorder(
                        label: "New Note",
                        defaultsKey: "Hotkey_NewNote",
                        defaultHotkey: .newNote
                    )
                    Divider()
                    HotkeyRecorder(
                        label: "Show All Notes",
                        defaultsKey: "Hotkey_AllNotes",
                        defaultHotkey: .allNotes
                    )
                    Divider()
                    HotkeyRecorder(
                        label: "Search Notes",
                        defaultsKey: "Hotkey_SearchNotes",
                        defaultHotkey: .searchNotes
                    )
                }
            }

            Text("Click a hotkey pill to record a new shortcut. Press Escape to cancel.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            Divider().padding(.vertical, 12)

            // ---- ABOUT ----
            sectionHeader("About")

            settingsRow {
                HStack {
                    Text("HDStickies")
                    Spacer()
                    Text("Version 1.2")
                        .foregroundColor(.secondary)
                }
            }
            settingsRow {
                HStack {
                    Text("Part of HDPro")
                    Spacer()
                    Text("by Kevin Winspear")
                        .foregroundColor(.secondary)
                }
            }

            // HDPro footer link
            Divider().padding(.vertical, 4)
            Button(action: {
                if let url = URL(string: "https://github.com/HDClick?tab=repositories") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Part of HDPro — View all apps")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .padding(.bottom, 4)
        }
        .padding(24)
        .frame(width: 400)
    }

    // ---- Reusable layout helpers ----

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.bottom, 4)
    }

    private func showFontPicker() {
        let fontManager = NSFontManager.shared
        fontManager.target = SettingsFontResponder.shared
        fontManager.action = #selector(SettingsFontResponder.changeFont(_:))
        SettingsFontResponder.shared.onFontChange = { font in
            defaultFontName = font.fontName
            defaultFontSize = font.pointSize
        }
        fontManager.orderFrontFontPanel(nil)
    }
}

// Font responder for Settings font picker
class SettingsFontResponder: NSResponder {
    static let shared = SettingsFontResponder()
    var onFontChange: ((NSFont) -> Void)?

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let manager = sender else { return }
        let newFont = manager.convert(NSFont.systemFont(ofSize: 13))
        onFontChange?(newFont)
    }
}
