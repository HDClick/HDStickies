// ============================================================
// AllNotesView.swift
// ============================================================
// Updated in v2d:
// - New Note button creates a FLOATING note, not an in-editor one
// - Colour stored in YAML frontmatter (Color: yellow)
// - Colour stripe in sidebar is clickable — cycles/picks colour
// - Editor background reflects the selected note's colour
// - Colour picker popover on stripe click
// ============================================================

import SwiftUI
import AppKit

// ============================================================
// NoteFile
// ============================================================
struct NoteFile: Identifiable, Equatable {
    let id: String
    let url: URL
    var title: String
    var content: String
    var rawContent: String
    var date: String
    var color: NoteColor
    var isPinned: Bool = false  // pinned/favourite — stored in UserDefaults by file path

    static func == (lhs: NoteFile, rhs: NoteFile) -> Bool { lhs.id == rhs.id }
}

// ============================================================
// AllNotesViewModel
// ============================================================
class AllNotesViewModel: ObservableObject {

    @Published var notes: [NoteFile] = []
    @Published var selectedID: String? = nil
    @Published var isLoading = false
    @Published var editingTitle: String = ""
    @Published var editingContent: String = ""
    @Published var editingColor: NoteColor = .yellow

    // Set this before calling loadNotes() — it will be
    // selected automatically once the file list is ready
    var pendingSelectPath: String? = nil

    // Pinned note IDs stored in UserDefaults
    private var pinnedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "HDStickies_PinnedNotes") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "HDStickies_PinnedNotes") }
    }

    func togglePin(id: String) {
        var pinned = pinnedIDs
        if pinned.contains(id) { pinned.remove(id) }
        else { pinned.insert(id) }
        pinnedIDs = pinned
        // Update in-memory array
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].isPinned = pinned.contains(id)
        }
        // Re-sort so pinned notes float to top
        sortNotes()
    }

    func isPinned(_ id: String) -> Bool { pinnedIDs.contains(id) }

    private func sortNotes() {
        notes.sort { (a: NoteFile, b: NoteFile) -> Bool in
            // Pinned notes always sort above unpinned
            if a.isPinned != b.isPinned { return a.isPinned }
            // Within same group, newest modification date first
            let aDate = (try? a.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let bDate = (try? b.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return aDate > bDate
        }
    }

    private var saveFolder: URL? { NoteWindowManager.shared.saveFolder }

    // --------------------------------------------------------
    // loadNotes()
    // --------------------------------------------------------
    func loadNotes() {
        guard let folder = saveFolder else { notes = []; return }
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try FileManager.default
                    .contentsOfDirectory(at: folder,
                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [.skipsHiddenFiles])
                    .filter { $0.pathExtension == "md" }
                    .sorted {
                        let aDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        let bDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        return aDate > bDate
                    }

                var noteFiles = files.compactMap { url -> NoteFile? in
                    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                    return self.parseNoteFile(url: url, raw: raw)
                }

                // Mark pinned notes
                let pinned = self.pinnedIDs
                for i in noteFiles.indices {
                    noteFiles[i].isPinned = pinned.contains(noteFiles[i].id)
                }

                DispatchQueue.main.async {
                    self.notes = noteFiles
                    self.sortNotes()
                    self.isLoading = false

                    // If search requested a specific note, select it now
                    // that the list is fully populated
                    if let pending = self.pendingSelectPath {
                        self.pendingSelectPath = nil
                        self.selectNote(id: pending)
                    } else if self.selectedID == nil || !noteFiles.contains(where: { $0.id == self.selectedID }) {
                        self.selectNote(id: noteFiles.first?.id)
                    }
                }
            } catch {
                DispatchQueue.main.async { self.notes = []; self.isLoading = false }
            }
        }
    }

    // --------------------------------------------------------
    // parseNoteFile() — now reads Color from YAML frontmatter
    // --------------------------------------------------------
    private func parseNoteFile(url: URL, raw: String) -> NoteFile {
        var title = url.deletingPathExtension().lastPathComponent
        var date = ""
        var color: NoteColor = .yellow
        var bodyContent = raw

        // Parse YAML frontmatter
        if raw.hasPrefix("---") {
            let lines = raw.components(separatedBy: "\n")
            var endIndex = -1
            for (i, line) in lines.enumerated() {
                if i == 0 { continue }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "---" { endIndex = i; break }

                // Date field
                if trimmed.lowercased().hasPrefix("date:") {
                    date = trimmed.replacingOccurrences(of: "date:", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                }
                // Color field
                if trimmed.lowercased().hasPrefix("color:") {
                    let colorName = trimmed
                        .replacingOccurrences(of: "color:", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    color = NoteColor(rawValue: colorName) ?? .yellow
                }
                // Tags field — read and ignore (keeps it out of body content)
                // In future we could filter by tag here
                if trimmed.lowercased().hasPrefix("tags:") {
                    // parsed but not used yet — reserved for future filtering
                    _ = trimmed.replacingOccurrences(of: "tags:", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if endIndex > 0 {
                bodyContent = lines.dropFirst(endIndex + 1).joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Extract title from first # heading
        for line in bodyContent.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("# ") {
                title = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Editable body = everything AFTER the first # heading line
        // This ensures neither YAML nor the title line appear in the editor
        var editableContent = bodyContent
        let bodyLines = bodyContent.components(separatedBy: "\n")
        if let headingIdx = bodyLines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }) {
            editableContent = bodyLines.dropFirst(headingIdx + 1).joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // No heading found — strip any stray --- lines just in case
            editableContent = bodyLines
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("---") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return NoteFile(id: url.path, url: url, title: title,
                        content: editableContent, rawContent: raw, date: date, color: color)
    }

    // --------------------------------------------------------
    // selectNote() — auto-saves current then switches
    // --------------------------------------------------------
    func selectNote(id: String?) {
        // Save current note BEFORE changing any state
        // We pass editingColor explicitly so the save uses the
        // CURRENT note's colour, not the next note's colour
        if let currentID = selectedID,
           let index = notes.firstIndex(where: { $0.id == currentID }) {
            saveCurrentEditing(to: index, color: editingColor)
        }

        selectedID = id

        // Now load the newly selected note into the editor
        if let id = id, let note = notes.first(where: { $0.id == id }) {
            editingTitle   = note.title
            editingContent = note.content
            editingColor   = note.color   // set AFTER saving previous
        } else {
            editingTitle = ""; editingContent = ""; editingColor = .yellow
        }
    }

    // --------------------------------------------------------
    // changeColor() — updates colour in memory + saves to file
    // --------------------------------------------------------
    func changeColor(_ color: NoteColor) {
        editingColor = color
        if let id = selectedID, let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].color = color
            saveCurrentEditing(to: index, color: color)
        }
    }

    // --------------------------------------------------------
    // saveCurrentEditing() — writes YAML + heading + body
    // Now includes Color in frontmatter
    // --------------------------------------------------------
    // color parameter is explicit — never reads self.editingColor
    // This prevents the bug where switching notes overwrites the
    // previous note's colour with the newly selected note's colour
    func saveCurrentEditing(to index: Int, color: NoteColor) {
        guard index < notes.count else { return }
        let note = notes[index]

        // Skip saving if completely empty
        let hasTitle   = !editingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasContent = !editingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasTitle || hasContent else { return }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        let fullContent = """
---
Date: \(note.date.isEmpty ? today : note.date)
Color: \(color.rawValue)
Tags: HDStickies
---

# \(editingTitle.isEmpty ? "Untitled Note" : editingTitle)

\(editingContent)
"""
        // Always write back to the ORIGINAL file url — never a new filename
        do {
            try fullContent.write(to: note.url, atomically: true, encoding: .utf8)
            notes[index].title      = editingTitle.isEmpty ? "Untitled Note" : editingTitle
            notes[index].content    = editingContent
            notes[index].rawContent = fullContent
            notes[index].color      = color
        } catch {
        }
    }

    func saveSelected() {
        if let id = selectedID, let index = notes.firstIndex(where: { $0.id == id }) {
            saveCurrentEditing(to: index, color: editingColor)
        }
    }

    func deleteNote(id: String) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        try? FileManager.default.trashItem(at: note.url, resultingItemURL: nil)
        notes.removeAll { $0.id == id }
        if selectedID == id { selectNote(id: notes.first?.id) }
    }

    // --------------------------------------------------------
    // createNewEditorNote()
    // Creates a blank note INSIDE the editor sidebar.
    // No floating window is opened.
    // The note is NOT written to disk until the user types
    // something AND either switches away or saves manually.
    // If the editor is closed with an empty new note, nothing saves.
    // --------------------------------------------------------
    func createNewEditorNote() {
        // Save the current note first before switching
        if let currentID = selectedID,
           let index = notes.firstIndex(where: { $0.id == currentID }) {
            saveCurrentEditing(to: index, color: editingColor)
        }

        let defaultColorName = UserDefaults.standard.string(forKey: "DefaultNoteColor") ?? "yellow"
        let color: NoteColor = defaultColorName == "random"
            ? (NoteColor.allCases.randomElement() ?? .yellow)
            : (NoteColor(rawValue: defaultColorName) ?? .yellow)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        // Create a temporary URL in the save folder
        // The file is NOT written to disk yet — only on save
        guard let folder = NoteWindowManager.shared.saveFolder else { return }
        let tempID = UUID().uuidString
        let tempURL = folder.appendingPathComponent("Untitled-\(tempID.prefix(8)).md")

        // Add a blank entry to the top of the sidebar
        let blank = NoteFile(
            id: tempURL.path,
            url: tempURL,
            title: "",
            content: "",
            rawContent: "",
            date: today,
            color: color
        )

        notes.insert(blank, at: 0)

        // Switch editor to this blank note
        selectedID = blank.id
        editingTitle   = ""
        editingContent = ""
        editingColor   = color
    }
}

// ============================================================
// AllNotesView
// ============================================================
struct AllNotesView: View {

    @ObservedObject var vm: AllNotesViewModel
    @State private var textView: NSTextView? = nil
    @State private var searchText: String = ""
    @State private var showColorPicker: String? = nil

    // Accepts an external ViewModel from MenuBarManager so state
    // persists across open/close cycles. Falls back to a new one if needed.
    init(externalViewModel: AllNotesViewModel? = nil) {
        _vm = ObservedObject(wrappedValue: externalViewModel ?? AllNotesViewModel())
    }

    // Link dialog handled via NSPanel — no state needed here

    private var filteredNotes: [NoteFile] {
        searchText.isEmpty ? vm.notes : vm.notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            rightPanel
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            checkPendingNote()
            vm.loadNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            vm.loadNotes()
        }
        // Listen for search-to-editor navigation notification
        .onReceive(NotificationCenter.default.publisher(for: .openNoteInEditor)) { notification in
            guard let path = notification.userInfo?["path"] as? String else {
                return
            }
            if vm.notes.isEmpty {
                vm.pendingSelectPath = path
                vm.loadNotes()
            } else {
                vm.selectNote(id: path)
            }
        }
        .onDisappear {
            // Window closing — save current note only if it has content
            // Empty new notes that were never typed in are silently discarded
            if let id = vm.selectedID,
               let index = vm.notes.firstIndex(where: { $0.id == id }) {
                let hasTitle   = !vm.editingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasContent = !vm.editingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if hasTitle || hasContent {
                    vm.saveCurrentEditing(to: index, color: vm.editingColor)
                }
                // If empty — do nothing, file was never created on disk
            }
        }
    }

    // ============================================================
    // SIDEBAR
    // ============================================================
    private var sidebar: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()

                // NEW NOTE — creates a blank note inside the editor
                Button(action: { vm.createNewEditorNote() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New note in editor")

                Button(action: { vm.loadNotes() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                TextField("Search notes", text: $searchText)
                    .font(.system(size: 12)).textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 10).padding(.bottom, 6)

            Divider()

            // List or empty states
            if NoteWindowManager.shared.saveFolder == nil {
                folderNotSetPrompt
            } else if vm.isLoading {
                ProgressView().padding(.top, 30)
            } else if filteredNotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text").font(.system(size: 28)).foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No notes yet" : "No results")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }.padding(.top, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredNotes) { note in
                            sidebarRow(note: note)
                        }
                    }
                    .padding(.vertical, 4).padding(.horizontal, 6)
                }
            }

            Spacer()
            Divider()
            Text("\(vm.notes.count) note\(vm.notes.count == 1 ? "" : "s")")
                .font(.system(size: 10)).foregroundColor(.secondary).padding(.vertical, 6)
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // ---- Sidebar row ----
    private func sidebarRow(note: NoteFile) -> some View {
        let isSelected = vm.selectedID == note.id

        return HStack(spacing: 0) {

            // ---- COLOUR STRIPE — clickable to change colour ----
            // Uses note.color.background which is read from the
            // Color: field in YAML frontmatter on load
            Rectangle()
                .fill(note.color.background)
                .frame(width: 5)
                .cornerRadius(2)
            .onTapGesture {
                // Show colour picker for this note
                showColorPicker = (showColorPicker == note.id) ? nil : note.id
                // Also select the note
                if vm.selectedID != note.id { vm.selectNote(id: note.id) }
            }
            .help("Click to change note colour")
            // Colour picker popover attached to the stripe
            .popover(isPresented: Binding(
                get: { showColorPicker == note.id },
                set: { if !$0 { showColorPicker = nil } }
            ), arrowEdge: .trailing) {
                colorPickerPopover
            }

            // ---- Note title + date ----
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Empty Note" : note.title)
                    .font(.system(size: 13, weight: note.title.isEmpty ? .regular : .medium))
                    .italic(note.title.isEmpty)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1).truncationMode(.tail)

                if !note.date.isEmpty {
                    Text(note.date)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)

            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { vm.selectNote(id: note.id) }
        .contextMenu {
            Button(vm.isPinned(note.id) ? "Unpin Note" : "Pin to Top") {
                vm.togglePin(id: note.id)
            }
            Divider()
            Button("Delete Note") { vm.deleteNote(id: note.id) }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(note.url.path, inFileViewerRootedAtPath: "")
            }
        }
    }

    // ---- Colour picker popover ----
    private var colorPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note Colour")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 4), spacing: 8) {
                ForEach(NoteColor.allCases) { color in
                    Button(action: {
                        vm.changeColor(color)
                        showColorPicker = nil
                    }) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(color.background)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(
                                    vm.editingColor == color ? Color.primary : Color.clear,
                                    lineWidth: 2
                                ))
                            Text(color.rawValue.capitalized)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 170)
    }

    private var folderNotSetPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28)).foregroundColor(.secondary)
            Text("No save folder set").font(.system(size: 12, weight: .medium))
            Text("Set one in Settings").font(.system(size: 11)).foregroundColor(.secondary)
        }.padding(.top, 30)
    }

    // ============================================================
    // RIGHT PANEL
    // ============================================================
    @ViewBuilder
    private var rightPanel: some View {
        if NoteWindowManager.shared.saveFolder == nil {
            noFolderView
        } else if let id = vm.selectedID,
                  let note = vm.notes.first(where: { $0.id == id }) {
            editorView(note: note)
        } else {
            emptyStateView
        }
    }

    private func editorView(note: NoteFile) -> some View {
        VStack(spacing: 0) {

            editorToolbar(note: note)
            Divider()

            // Title field
            TextField("Title", text: $vm.editingTitle)
                .font(.system(size: 20, weight: .semibold))
                .textFieldStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 20).padding(.bottom, 10)

            Divider().padding(.horizontal, 24).opacity(0.3)

            // Body editor
            AllNotesTextEditor(
                text: $vm.editingContent,
                font: NSFont.systemFont(ofSize: CGFloat(
                    UserDefaults.standard.double(forKey: "DefaultFontSize") > 0
                        ? UserDefaults.standard.double(forKey: "DefaultFontSize") : 13
                )),
                onTextViewReady: { tv in self.textView = tv }
            )
            .padding(.horizontal, 18).padding(.vertical, 8)

            // Status bar
            Divider()
            HStack {
                if !note.date.isEmpty {
                    Text("Created \(note.date)")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(vm.editingContent.split(separator: " ").count) words")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Button(action: { vm.saveSelected() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }.font(.system(size: 11))
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("Save (also saves automatically when switching notes)")
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(vm.editingColor.toolbarColor.opacity(0.5))
        }
        // ---- Editor background reflects the note's colour ----
        .background(vm.editingColor.background.opacity(0.12))
    }

    // ---- Editor toolbar ----
    private func editorToolbar(note: NoteFile) -> some View {
        HStack(spacing: 4) {

            // Colour dot — also opens colour picker
            Button(action: { showColorPicker = (showColorPicker == note.id) ? nil : note.id }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.editingColor.background)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    Text(vm.editingColor.rawValue.capitalized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Change note colour")
            .popover(isPresented: Binding(
                get: { showColorPicker == note.id },
                set: { if !$0 { showColorPicker = nil } }
            ), arrowEdge: .bottom) {
                colorPickerPopover
            }

            Divider().frame(height: 16).padding(.horizontal, 4)

            // Format buttons
            Group {
                fmtBtn("bold")          { wrap("**", "**") }
                fmtBtn("italic")        { wrap("*", "*") }
                fmtBtn("strikethrough") { wrap("~~", "~~") }
                fmtBtn("highlighter")   { wrap("==", "==") }
                fmtBtn("list.bullet")   { insertLine("- ") }
                fmtBtn("checklist")     { insertLine("- [ ] ") }
            }

            Divider().frame(height: 16).padding(.horizontal, 2)

            // Code block
            fmtBtn("chevron.left.forwardslash.chevron.right") {
                insertCodeBlock()
            }

            // Inline code
            fmtBtn("chevron.left.slash.chevron.right") {
                wrap("`", "`")
            }

            // Link — opens NSPanel dialog
            fmtBtn("link") {
                LinkDialog.show { name, url in
                    let text = name.isEmpty ? "[\(url)](\(url))" : "[\(name)](\(url))"
                    if let tv = self.textView {
                        tv.insertText(text, replacementRange: tv.selectedRange())
                    } else {
                        self.vm.editingContent += text
                    }
                }
            }

            // Image — opens file picker
            fmtBtn("photo") {
                insertImage()
            }

            // Callout — opens callout dialog
            fmtBtn("text.badge.plus") {
                CalloutDialog.show { markdown in
                    if let tv = self.textView {
                        tv.insertText(markdown, replacementRange: tv.selectedRange())
                    } else {
                        self.vm.editingContent += markdown
                    }
                }
            }

            // Numbered list
            fmtBtn("list.number") {
                insertLine("1. ")
            }

            Spacer()

            // Show in Finder
            Button(action: {
                NSWorkspace.shared.selectFile(note.url.path, inFileViewerRootedAtPath: "")
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain).help("Show in Finder")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(vm.editingColor.toolbarColor.opacity(0.5))
    }

    private func fmtBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12)).foregroundColor(.secondary)
                .frame(width: 26, height: 22)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
        }.buttonStyle(.plain)
    }

    private func wrap(_ prefix: String, _ suffix: String) {
        guard let tv = textView else { vm.editingContent += "\(prefix)text\(suffix)"; return }
        let range = tv.selectedRange()
        if range.length > 0, let r = Range(range, in: tv.string) {
            tv.insertText("\(prefix)\(String(tv.string[r]))\(suffix)", replacementRange: range)
        } else {
            tv.insertText("\(prefix)text\(suffix)", replacementRange: range)
        }
    }

    private func insertLine(_ text: String) {
        guard let tv = textView else { vm.editingContent += "\n\(text)"; return }
        let range = tv.selectedRange()
        tv.insertText("\n\(text)", replacementRange: NSRange(location: range.location + range.length, length: 0))
    }

    // Insert a fenced code block at cursor
    private func insertCodeBlock() {
        let block = "\n```\ncode here\n```\n"
        if let tv = textView {
            tv.insertText(block, replacementRange: tv.selectedRange())
        } else {
            vm.editingContent += block
        }
    }

    // Open file picker to insert an image as markdown
    private func insertImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Insert Image"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            // Insert as markdown image link
            // Uses the filename as alt text
            let altText = url.deletingPathExtension().lastPathComponent
            let markdown = "![\(altText)](\(url.path))"
            DispatchQueue.main.async {
                if let tv = self.textView {
                    tv.insertText(markdown, replacementRange: tv.selectedRange())
                } else {
                    self.vm.editingContent += markdown
                }
            }
        }
    }

    // --------------------------------------------------------
    // checkPendingNote()
    // Check AppState for a pending path set by search panel
    // --------------------------------------------------------
    private func checkPendingNote() {
        if let path = AppState.shared.pendingNotePath {
            AppState.shared.pendingNotePath = nil
            vm.pendingSelectPath = path
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.3))
            Text("Select a note")
                .font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noFolderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.3))
            Text("No save folder set")
                .font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
            Text("Set a folder in Settings (⌘,) to see your notes here")
                .font(.system(size: 13)).foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ============================================================
// AllNotesTextEditor
// ============================================================
struct AllNotesTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var onTextViewReady: (NSTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.font = font
        tv.textContainerInset = NSSize(width: 8, height: 8)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        DispatchQueue.main.async { onTextViewReady(tv) }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        if tv.string != text {
            let range = tv.selectedRange()
            tv.string = text
            let safe = min(range.location, tv.string.count)
            tv.setSelectedRange(NSRange(location: safe, length: 0))
        }
        tv.font = font
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AllNotesTextEditor
        init(_ p: AllNotesTextEditor) { parent = p }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
