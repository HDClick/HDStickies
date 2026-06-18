// ============================================================
// NoteWindowController.swift
// ============================================================
// Updated in v2 to accept a pre-built NoteViewModel so the
// same VM can be shared with AllNotesView for live editing.
// ============================================================

import AppKit
import SwiftUI

class NoteWindowController: NSWindowController {
    private var dragController: WindowDragController?

    let noteID: String
    let viewModel: NoteViewModel
    // If set, saves back to this URL on close (used for "Open as Floating")
    var saveURL: URL? = nil

    // ---- New note ----
    init(viewModel: NoteViewModel, offset: CGFloat = 0, saveURL: URL? = nil) {
        self.saveURL = saveURL
        self.noteID = viewModel.id
        self.viewModel = viewModel

        let window = NoteWindowController.makeWindow(
            x: 120 + offset, y: 120 + offset, width: 280, height: 320
        )
        let view = NoteView(viewModel: viewModel)
        window.contentView = NSHostingView(rootView: view)

        super.init(window: window)
        window.delegate = self
        // Attach pan gesture for drag strip — must be after super.init
        self.dragController = WindowDragController(window: window)
    }

    // ---- Restored note (from saved state) ----
    init(viewModel: NoteViewModel, state: NoteState) {
        self.noteID = viewModel.id
        self.viewModel = viewModel

        let window = NoteWindowController.makeWindow(
            x: state.x, y: state.y, width: state.width, height: state.height
        )
        let view = NoteView(viewModel: viewModel)
        window.contentView = NSHostingView(rootView: view)

        super.init(window: window)
        window.delegate = self
        // Attach pan gesture for drag strip — must be after super.init
        self.dragController = WindowDragController(window: window)
    }

    private static func makeWindow(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NoteWindow {
        let window = NoteWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Drag via hover strip at top — not whole background
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.minSize = NSSize(width: 220, height: 120)

        // Liquid Glass needs the window to be transparent
        // so the glass effect can see through to what's behind
        let liquidGlass = UserDefaults.standard.bool(forKey: "LiquidGlass")
        if liquidGlass {
            window.backgroundColor = .clear
            window.isOpaque = false
        }

        return window
    }

    // --------------------------------------------------------
    // centreOnScreen()
    // Places the window in the centre of the main display.
    // Called after showWindow() for new notes so they appear
    // right where the user is looking rather than in a corner.
    // For restored notes we skip this — they remember their position.
    // --------------------------------------------------------
    func centreOnScreen() {
        guard let window = window,
              let screen = NSScreen.main else { return }

        let screenFrame  = screen.visibleFrame  // excludes menu bar and dock
        let windowSize   = window.frame.size

        let centreX = screenFrame.origin.x + (screenFrame.width  - windowSize.width)  / 2
        let centreY = screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2

        // Slight upward offset — visually feels more centred than true centre
        let offsetY = centreY + 40

        window.setFrameOrigin(NSPoint(x: centreX, y: offsetY))
    }

    func currentState() -> NoteState? {
        guard let window = window else { return nil }
        let frame = window.frame
        return NoteState(
            id: noteID,
            title: viewModel.title,
            content: viewModel.content,
            colorName: viewModel.noteColor.rawValue,
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height,
            isCollapsed: viewModel.isCollapsed,
            fontName: viewModel.fontName,
            fontSize: viewModel.fontSize
        )
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension NoteWindowController: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        // Save the note to disk when the window closes
        // This is the ONLY time floating notes save — not on every keystroke
        saveNoteToFile()
        NoteWindowManager.shared.removeNote(withID: noteID)
    }

    // --------------------------------------------------------
    // saveNoteToFile()
    // Writes the note content as a .md file with YAML frontmatter.
    // Called on window close and on app quit.
    // --------------------------------------------------------
    func saveNoteToFile() {
        // Don't save if note is completely empty — no title, no content
        // This means creating a note and closing it without typing anything
        // leaves zero files on disk
        let hasTitle   = !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasContent = !viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasTitle || hasContent else {
            return
        }

        guard let folder = NoteWindowManager.shared.saveFolder else {
            return
        }

        let title = viewModel.title.isEmpty ? "Untitled Note" : viewModel.title

        // Safe filename from title
        let safeTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")

        let fileName = "\(safeTitle)-\(noteID.prefix(8)).md"
        let fileURL = folder.appendingPathComponent(fileName)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        let fullContent = """
---
Date: \(today)
Color: \(viewModel.noteColor.rawValue)
Tags: HDStickies
---

# \(title)

\(viewModel.content)
"""
        do {
            try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
        }
    }
}

class NoteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
