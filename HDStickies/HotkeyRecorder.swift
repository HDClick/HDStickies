// ============================================================
// HotkeyRecorder.swift
// ============================================================
// A custom hotkey recorder control for the Settings window.
//
// How it works:
// - Shows the current hotkey as a pill (e.g. "⇧⌥⌘N")
// - Click to enter "recording" mode — it listens for the next
//   key combination you press
// - Validates it has at least one modifier key
// - Saves to UserDefaults and notifies MenuBarManager to
//   update the CGEventTap
//
// In Delphi terms: like a TEdit that captures raw key events
// instead of characters.
// ============================================================

import SwiftUI
import AppKit
import Carbon

// ============================================================
// HotkeyDefinition — stores a hotkey as key code + modifiers
// Codable so it can be saved to UserDefaults as JSON
// ============================================================
struct HotkeyDefinition: Codable, Equatable {
    var keyCode: Int64       // Raw macOS key code (e.g. 45 = N, 0 = A)
    var modifiers: UInt64    // CGEventFlags raw value

    // Default hotkeys
    static let newNote     = HotkeyDefinition(keyCode: 45, modifiers: CGEventFlags([.maskShift, .maskAlternate, .maskCommand]).rawValue)
    static let allNotes    = HotkeyDefinition(keyCode: 0,  modifiers: CGEventFlags([.maskShift, .maskAlternate, .maskCommand]).rawValue)
    static let searchNotes = HotkeyDefinition(keyCode: 1,  modifiers: CGEventFlags([.maskShift, .maskAlternate, .maskCommand]).rawValue)

    // --------------------------------------------------------
    // displayString — human readable like "⇧⌥⌘N"
    // --------------------------------------------------------
    var displayString: String {
        let flags = CGEventFlags(rawValue: modifiers)
        var parts = ""
        if flags.contains(.maskControl)  { parts += "⌃" }
        if flags.contains(.maskAlternate){ parts += "⌥" }
        if flags.contains(.maskShift)    { parts += "⇧" }
        if flags.contains(.maskCommand)  { parts += "⌘" }
        parts += keyName
        return parts
    }

    // Convert key code to a readable key name
    var keyName: String {
        // Common key codes
        let names: [Int64: String] = [
            0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X",
            8:"C", 9:"V", 11:"B", 12:"Q", 13:"W", 14:"E", 15:"R",
            16:"Y", 17:"T", 31:"O", 32:"U", 34:"I", 35:"P",
            37:"L", 38:"J", 40:"K", 45:"N", 46:"M",
            18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5",
            24:"=", 25:"9", 26:"7", 27:"-", 28:"8", 29:"0",
            36:"↩", 48:"⇥", 49:"Space", 51:"⌫", 53:"⎋",
            123:"←", 124:"→", 125:"↓", 126:"↑"
        ]
        return names[keyCode] ?? "(\(keyCode))"
    }

    // Load from UserDefaults (or return default if not set)
    static func load(key: String, default def: HotkeyDefinition) -> HotkeyDefinition {
        guard let data = UserDefaults.standard.data(forKey: key),
              let hotkey = try? JSONDecoder().decode(HotkeyDefinition.self, from: data) else {
            return def
        }
        return hotkey
    }

    // Save to UserDefaults
    func save(key: String) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// ============================================================
// HotkeyRecorder — the SwiftUI view
// ============================================================
struct HotkeyRecorder: View {

    let label: String           // e.g. "New Note"
    let defaultsKey: String     // UserDefaults key to save to

    @State private var hotkey: HotkeyDefinition
    @State private var isRecording = false
    @State private var errorMessage: String? = nil

    // Monitor for key events while recording
    @State private var eventMonitor: Any? = nil

    init(label: String, defaultsKey: String, defaultHotkey: HotkeyDefinition) {
        self.label = label
        self.defaultsKey = defaultsKey
        _hotkey = State(initialValue: HotkeyDefinition.load(key: defaultsKey, default: defaultHotkey))
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))

            Spacer()

            // Error message if invalid key combo
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            // The recorder pill button
            Button(action: toggleRecording) {
                HStack(spacing: 6) {
                    if isRecording {
                        // Pulsing recording indicator
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Press keys…")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text(hotkey.displayString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? Color.red.opacity(0.1)
                              : Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.red.opacity(0.4) : Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Press your hotkey combination" : "Click to record a new hotkey")

            // Reset to default button
            Button(action: resetToDefault) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reset to default")
        }
        .padding(.vertical, 4)
        // Stop recording if view disappears
        .onDisappear { stopRecording() }
    }

    // --------------------------------------------------------
    // toggleRecording()
    // --------------------------------------------------------
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // --------------------------------------------------------
    // startRecording()
    // Installs a LOCAL event monitor (only fires when our
    // Settings window is key — safer than global monitor here)
    // --------------------------------------------------------
    private func startRecording() {
        isRecording = true
        errorMessage = nil

        // NSEvent.addLocalMonitorForEvents monitors keyboard events
        // only when THIS app's window is focused — appropriate
        // for a settings panel where the user is deliberately
        // typing a hotkey
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in

            // Escape = cancel recording
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Must have at least one of: ⌘ ⌃ ⌥
            // Pure Shift alone or no modifiers = reject
            let hasRequiredModifier = flags.contains(.command) ||
                                      flags.contains(.control) ||
                                      flags.contains(.option)

            guard hasRequiredModifier else {
                self.errorMessage = "Add ⌘, ⌥ or ⌃"
                return nil
            }

            // Convert NSEvent modifiers to CGEventFlags
            var cgFlags: CGEventFlags = []
            if flags.contains(.command)  { cgFlags.insert(.maskCommand) }
            if flags.contains(.option)   { cgFlags.insert(.maskAlternate) }
            if flags.contains(.shift)    { cgFlags.insert(.maskShift) }
            if flags.contains(.control)  { cgFlags.insert(.maskControl) }

            // Save the new hotkey
            let newHotkey = HotkeyDefinition(
                keyCode: Int64(event.keyCode),
                modifiers: cgFlags.rawValue
            )

            self.hotkey = newHotkey
            newHotkey.save(key: self.defaultsKey)
            self.errorMessage = nil

            // Tell MenuBarManager to reload hotkeys with new values
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)

            self.stopRecording()
            return nil  // Consume the event so it doesn't type into fields
        }
    }

    // --------------------------------------------------------
    // stopRecording()
    // --------------------------------------------------------
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // --------------------------------------------------------
    // resetToDefault()
    // --------------------------------------------------------
    private func resetToDefault() {
        let def: HotkeyDefinition
        if defaultsKey == "Hotkey_NewNote" {
            def = .newNote
        } else if defaultsKey == "Hotkey_AllNotes" {
            def = .allNotes
        } else {
            def = .searchNotes
        }
        hotkey = def
        def.save(key: defaultsKey)
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
    }
}

// Notification so MenuBarManager knows to reload hotkeys
extension Notification.Name {
    static let hotkeyChanged = Notification.Name("HDStickies_HotkeyChanged")
}
