// ============================================================
// NoteWindowManager.swift
// ============================================================
// Manages all floating note windows.
// Updated in v2:
// - Now an ObservableObject so AllNotesView can observe it
// - Publishes viewModels array so sidebar stays in sync
// - Added showNote(withID:) and closeNote(withID:) helpers
// ============================================================

import SwiftUI
import AppKit

struct NoteState: Codable {
    var id: String
    var title: String
    var content: String
    var colorName: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var isCollapsed: Bool
    var fontName: String
    var fontSize: Double
}

class NoteWindowManager: ObservableObject {

    static let shared = NoteWindowManager()

    // Published so AllNotesView sidebar updates automatically
    // when notes are added, removed or changed
    @Published var viewModels: [NoteViewModel] = []

    private var noteWindows: [NoteWindowController] = []
    // Tracks windows opened via "Open as Floating" from All Notes
    // keyed by file URL path so we can detect duplicates

    private let persistenceKey = "HDStickies_OpenNotes"

    var saveFolder: URL? {
        get {
            if let path = UserDefaults.standard.string(forKey: "SaveFolder") {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: "SaveFolder")
        }
    }

    // --------------------------------------------------------
    // controller(forID:) — returns the window controller for a note ID
    // Used by NoteView's Save button to call saveNoteToFile directly
    // --------------------------------------------------------
    func controller(forID id: String) -> NoteWindowController? {
        return noteWindows.first { $0.noteID == id }
    }

    // --------------------------------------------------------
    // createNewNote()
    // --------------------------------------------------------
    func createNewNote(withColor color: NoteColor = .red) {
        let noteID = UUID().uuidString
        let offset = CGFloat(noteWindows.count % 8) * 24

        let vm = NoteViewModel(
            id: noteID,
            color: color,
            title: "",
            content: "",
            isCollapsed: false,
            fontName: UserDefaults.standard.string(forKey: "DefaultFontName") ?? "System",
            fontSize: UserDefaults.standard.double(forKey: "DefaultFontSize") > 0
                ? UserDefaults.standard.double(forKey: "DefaultFontSize") : 13
        )

        let controller = NoteWindowController(viewModel: vm, offset: offset)
        noteWindows.append(controller)
        // Don't add to viewModels yet — only add after note is saved to disk
        // This prevents ghost entries in All Notes sidebar for unsaved notes
        controller.showWindow(nil)
        // Centre new notes on screen — restored notes keep their saved position
        controller.centreOnScreen()
        controller.window?.makeKeyAndOrderFront(nil)
    }

    // --------------------------------------------------------
    // createFloatingNote() — opens an existing .md file as a
    // floating note without creating a new file on disk.
    // Saves back to existingURL on close.
    // --------------------------------------------------------


    // --------------------------------------------------------
    // createNote(from state) — restores a saved note
    // --------------------------------------------------------
    func createNote(from state: NoteState) {
        let color = NoteColor(rawValue: state.colorName) ?? .red

        // Strip YAML frontmatter from content if present
        // This ensures the floating note editor never shows --- blocks
        let cleanContent = NoteWindowManager.stripYAML(from: state.content)

        let vm = NoteViewModel(
            id: state.id,
            color: color,
            title: state.title,
            content: cleanContent,
            isCollapsed: state.isCollapsed,
            fontName: state.fontName,
            fontSize: state.fontSize
        )

        let controller = NoteWindowController(viewModel: vm, state: state)
        noteWindows.append(controller)
        viewModels.append(vm)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    // --------------------------------------------------------
    // showNote() — brings a specific floating note to front
    // --------------------------------------------------------
    func showNote(withID id: String) {
        if let controller = noteWindows.first(where: { $0.noteID == id }) {
            controller.window?.orderFront(nil)
            controller.window?.deminiaturize(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // --------------------------------------------------------
    // closeNote() — closes a note programmatically
    // --------------------------------------------------------
    func closeNote(withID id: String) {
        if let controller = noteWindows.first(where: { $0.noteID == id }) {
            controller.window?.close()
        }
    }

    // --------------------------------------------------------
    // showAllNotes() — brings all notes to front
    // --------------------------------------------------------
    func showAllNotes() {
        for controller in noteWindows {
            controller.window?.orderFront(nil)
            controller.window?.deminiaturize(nil)
        }
    }

    // --------------------------------------------------------
    // removeNote() — called when a window closes
    // --------------------------------------------------------
    func removeNote(withID id: String) {
        noteWindows.removeAll { $0.noteID == id }
        viewModels.removeAll { $0.id == id }
    }

    // --------------------------------------------------------
    // saveNoteStates() — called on quit
    // --------------------------------------------------------
    func saveNoteStates() {
        // Save each open note to disk before quitting
        for controller in noteWindows {
            controller.saveNoteToFile()
        }

        // Also save window positions/state for restore on relaunch
        var states: [NoteState] = []
        for controller in noteWindows {
            if let state = controller.currentState() {
                states.append(state)
            }
        }
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    // --------------------------------------------------------
    // restoreNotes() — called on launch
    // --------------------------------------------------------
    func restoreNotes() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let states = try? JSONDecoder().decode([NoteState].self, from: data) else {
            return
        }
        for state in states {
            createNote(from: state)
        }
    }

    // --------------------------------------------------------
    // chooseSaveFolder()
    // --------------------------------------------------------
    func chooseSaveFolder(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose where HDStickies saves your markdown notes"
        panel.begin { response in
            if response == .OK {
                self.saveFolder = panel.url
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }

    // --------------------------------------------------------
    // saveNote() — writes .md file
    // --------------------------------------------------------
    // --------------------------------------------------------
    // stripYAML() — removes frontmatter from raw .md content
    // Called when restoring notes so YAML never shows in editor
    // --------------------------------------------------------
    static func stripYAML(from raw: String) -> String {
        guard raw.hasPrefix("---") else { return raw }
        let lines = raw.components(separatedBy: "\n")
        var endIndex = -1
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                endIndex = i
                break
            }
        }
        guard endIndex > 0 else { return raw }

        // Drop frontmatter and the first # heading line
        var body = lines.dropFirst(endIndex + 1).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove the # Title line — title is stored separately in NoteState
        let bodyLines = body.components(separatedBy: "\n")
        if let headingIdx = bodyLines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }) {
            body = bodyLines.dropFirst(headingIdx + 1).joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return body
    }

    func saveNote(id: String, title: String, content: String) {
        guard let folder = saveFolder else { return }
        // Use same filename logic as NoteWindowController.saveNoteToFile
        // so Save button and window-close always write to the same file
        let safeTitle = title.isEmpty ? id.prefix(8).description :
            title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "-")
        let fileName = "\(safeTitle)-\(id.prefix(8)).md"
        let fileURL = folder.appendingPathComponent(fileName)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
        }
    }
}
