// ============================================================
// NoteView.swift
// ============================================================
// The visual layout of each HDStickies note.
// New features in this version:
// - Uses NoteViewModel (shared state with controller)
// - Font picker in Text format dropdown
// - Text highlighting via markdown ==text==
// - Better text insertion using NSTextView selection
// - Window position/size tracked automatically
// ============================================================

import SwiftUI
import AppKit

struct NoteView: View {

    // ObservedObject means: redraw when viewModel publishes changes
    @ObservedObject var viewModel: NoteViewModel
    @AppStorage("LiquidGlass") private var liquidGlass = false

    // Local UI state (dropdowns, save status)
    @State private var showListMenu  = false
    @State private var showTextMenu  = false
    @State private var showMoreMenu  = false
    @State private var lastSaved     = "Not saved yet"
    @State private var hostingWindow: NSWindow?

    // The NSTextView inside the TextEditor — needed for
    // selection-aware text insertion
    @State private var textView: NSTextView?

    var body: some View {
        VStack(spacing: 0) {
            header

            if !viewModel.isCollapsed {
                titleField
                Divider().background(viewModel.noteColor.textColor.opacity(0.15))
                textArea
                bottomBar
            }
        }
        .foregroundColor(viewModel.noteColor.textColor)
        .modifier(LiquidGlassModifier(
            enabled: liquidGlass,
            fallbackColor: viewModel.noteColor.background
        ))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        .background(WindowAccessor { window in
            self.hostingWindow = window
            updateWindowSize()
        })
        .onChange(of: viewModel.isCollapsed) { _ in updateWindowSize() }
    }

    // ============================================================
    // HEADER
    // ============================================================
    private var header: some View {
        HStack(spacing: 6) {

            // X — close
            Button(action: closeNote) {
                circleButton(icon: "xmark")
            }
            .buttonStyle(.plain)
            .help("Close note")

            // Collapse / expand
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isCollapsed.toggle()
                }
            }) {
                circleButton(icon: viewModel.isCollapsed ? "chevron.right" : "chevron.down")
            }
            .buttonStyle(.plain)
            .help(viewModel.isCollapsed ? "Expand" : "Collapse")

            // Title shown when collapsed
            if viewModel.isCollapsed {
                Text(viewModel.title.isEmpty ? "Untitled" : viewModel.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(viewModel.noteColor.textColor.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if !viewModel.isCollapsed {

                // Lists dropdown
                Button(action: { toggleMenu(list: true) }) {
                    iconButton("list.bullet")
                }
                .buttonStyle(.plain)
                .help("Lists")
                .popover(isPresented: $showListMenu, arrowEdge: .bottom) { listMenuContent }

                // Text / Font dropdown
                Button(action: { toggleMenu(text: true) }) {
                    iconButton("a.circle")
                }
                .buttonStyle(.plain)
                .help("Text & Font")
                .popover(isPresented: $showTextMenu, arrowEdge: .bottom) { textMenuContent }

                // More dropdown
                Button(action: { toggleMenu(more: true) }) {
                    iconButton("ellipsis.circle")
                }
                .buttonStyle(.plain)
                .help("More")
                .popover(isPresented: $showMoreMenu, arrowEdge: .bottom) { moreMenuContent }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(viewModel.noteColor.toolbarColor)
    }

    private func circleButton(icon: String) -> some View {
        ZStack {
            Circle()
                .fill(viewModel.noteColor.textColor.opacity(0.15))
                .frame(width: 20, height: 20)
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(viewModel.noteColor.textColor.opacity(0.7))
        }
    }

    private func iconButton(_ name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.noteColor.textColor.opacity(0.1))
                .frame(width: 26, height: 26)
            Image(systemName: name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(viewModel.noteColor.textColor.opacity(0.75))
        }
    }

    private func toggleMenu(list: Bool = false, text: Bool = false, more: Bool = false) {
        showListMenu = list
        showTextMenu = text
        showMoreMenu = more
    }

    // ============================================================
    // LISTS DROPDOWN
    // ============================================================
    private var listMenuContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            popoverTitle("Lists")
            menuRow(icon: "list.bullet",      label: "Bullet List")    { insertAtNewLine("- ") }
            menuRow(icon: "minus",             label: "Dashed List")    { insertAtNewLine("— ") }
            menuRow(icon: "list.number",       label: "Numbered List")  { insertAtNewLine("1. ") }
            Divider().background(Color.white.opacity(0.15)).padding(.vertical, 4)
            menuRow(icon: "checklist",         label: "Checklist")      { insertAtNewLine("- [ ] ") }
            menuRow(icon: "checkmark.circle",  label: "Checked Item")   { insertAtNewLine("- [x] ") }
        }
        .padding(10)
        .frame(width: 200)
        .background(Color.black.opacity(0.92))
    }

    // ============================================================
    // TEXT & FONT DROPDOWN
    // ============================================================
    private var textMenuContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            popoverTitle("Text Format")
            menuRow(icon: "bold",                        label: "Bold")           { wrapSelection(prefix: "**",   suffix: "**") }
            menuRow(icon: "italic",                      label: "Italic")         { wrapSelection(prefix: "*",    suffix: "*") }
            menuRow(icon: "underline",                   label: "Underline")      { wrapSelection(prefix: "<u>", suffix: "</u>") }
            menuRow(icon: "strikethrough",               label: "Strikethrough")  { wrapSelection(prefix: "~~",   suffix: "~~") }
            menuRow(icon: "highlighter",                 label: "Highlight")      { wrapSelection(prefix: "==",   suffix: "==") }
            Divider().padding(.vertical, 4)
            menuRow(icon: "textformat.size.larger",      label: "Heading 1")      { insertAtNewLine("# ") }
            menuRow(icon: "textformat.size",             label: "Heading 2")      { insertAtNewLine("## ") }
            menuRow(icon: "textformat.size.smaller",     label: "Heading 3")      { insertAtNewLine("### ") }
            Divider().padding(.vertical, 4)

            // Insert section
            popoverTitle("Insert")
            menuRow(icon: "chevron.left.forwardslash.chevron.right", label: "Code Block") {
                insertCodeBlock()
            }
            menuRow(icon: "quote.opening",                           label: "Quote")         { wrapSelectionAsQuote() }
            menuRow(icon: "link",                  label: "Link…")         { insertLink() }
            menuRow(icon: "photo",                 label: "Image…")        { insertImage() }
            menuRow(icon: "text.badge.plus",       label: "Callout…")      { insertCallout() }
            Divider().background(Color.white.opacity(0.15)).padding(.vertical, 4)

            // Font section
            popoverTitle("Font")

            // Font size stepper
            HStack {
                Image(systemName: "textformat.size")
                    .frame(width: 18)
                    .foregroundColor(.secondary)
                Text("Size")
                    .font(.system(size: 13))
                Spacer()
                Button(action: { if viewModel.fontSize > 9 { viewModel.fontSize -= 1 }}) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                Text("\(Int(viewModel.fontSize))")
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 28)
                Button(action: { if viewModel.fontSize < 32 { viewModel.fontSize += 1 }}) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)

            // Font picker button — opens macOS native font panel
            menuRow(icon: "f.cursive", label: "Choose Font…") {
                showFontPicker()
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(Color.black.opacity(0.92))
    }

    // ============================================================
    // MORE DROPDOWN
    // ============================================================
    private var moreMenuContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            popoverTitle("More")

            menuRow(icon: "plus.square",  label: "New Note") {
                NoteWindowManager.shared.createNewNote(withColor: viewModel.noteColor)
                showMoreMenu = false
            }

            menuRow(icon: "folder", label: "Choose Save Folder…") {
                showMoreMenu = false
                NoteWindowManager.shared.chooseSaveFolder { _ in }
            }

            Divider().padding(.vertical, 4)

            // Colour picker row
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .frame(width: 18)
                    .foregroundColor(.secondary)
                Text("Colour")
                    .font(.system(size: 13))
                Spacer()
                ForEach(NoteColor.allCases) { color in
                    Button(action: { viewModel.noteColor = color }) {
                        Circle()
                            .fill(color.background)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(
                                viewModel.noteColor == color ? Color.primary : Color.clear,
                                lineWidth: 2
                            ))
                    }
                    .buttonStyle(.plain)
                    .help(color.displayName)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
        }
        .padding(10)
        .frame(width: 220)
        .background(Color.black.opacity(0.92))
    }

    // ============================================================
    // TITLE FIELD
    // ============================================================
    private var titleField: some View {
        TextField("Set a title", text: $viewModel.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(viewModel.noteColor.textColor)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // No auto-save on keystroke — saves on window close only
    }

    // ============================================================
    // TEXT AREA — with selection tracking
    // ============================================================
    private var textArea: some View {
        SelectionAwareTextEditor(
            text: $viewModel.content,
            font: viewModel.resolvedNSFont,
            textColor: NSColor(viewModel.noteColor.textColor),
            onTextViewReady: { tv in self.textView = tv }
        )
        .background(Color.clear)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onChange(of: viewModel.content) { _ in autoSave() }
    }

    // ============================================================
    // BOTTOM BAR
    // ============================================================
    private var bottomBar: some View {
        HStack {
            Text("\(wordCount) words")
                .font(.system(size: 10))
                .foregroundColor(viewModel.noteColor.textColor.opacity(0.4))
            Spacer()
            Text(lastSaved)
                .font(.system(size: 10))
                .foregroundColor(viewModel.noteColor.textColor.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(viewModel.noteColor.toolbarColor)
    }

    // ============================================================
    // HELPER VIEWS
    // ============================================================

    private func popoverTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
    }

    private func menuRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            showListMenu = false
            showTextMenu = false
            showMoreMenu = false
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundColor(.white.opacity(0.6))
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ============================================================
    // FUNCTIONS
    // ============================================================

    private var wordCount: Int {
        viewModel.content.split(separator: " ").count
    }

    private func closeNote() {
        hostingWindow?.close()
    }

    private func updateWindowSize() {
        guard let window = hostingWindow else { return }
        if viewModel.isCollapsed {
            var frame = window.frame
            let newHeight: CGFloat = 40
            frame.origin.y += frame.height - newHeight
            frame.size.height = newHeight
            window.setFrame(frame, display: true, animate: true)
            window.minSize = NSSize(width: 200, height: 40)
            window.maxSize = NSSize(width: 2000, height: 40)
        } else {
            window.minSize = NSSize(width: 200, height: 200)
            window.maxSize = NSSize(width: 2000, height: 2000)
            if window.frame.height < 200 {
                var frame = window.frame
                let newHeight: CGFloat = 320
                frame.origin.y -= newHeight - frame.height
                frame.size.height = newHeight
                window.setFrame(frame, display: true, animate: true)
            }
        }
    }

    // Insert text at start of a new line
    private func insertAtNewLine(_ text: String) {
        if let tv = textView {
            let selected = tv.selectedRange()
            let insertText = viewModel.content.isEmpty ? text : "\n\(text)"
            tv.insertText(insertText, replacementRange: NSRange(location: selected.location + selected.length, length: 0))
        } else {
            viewModel.content += "\n\(text)"
        }
    }

    // Insert a fenced code block
    private func insertCodeBlock() {
        let block = "\n```\ncode here\n```\n"
        if let tv = textView {
            tv.insertText(block, replacementRange: tv.selectedRange())
        } else {
            viewModel.content += block
        }
        showTextMenu = false
    }

    // Open link dialog as a floating NSPanel
    private func insertLink() {
        showTextMenu = false
        LinkDialog.show { name, url in
            let markdown = name.isEmpty ? "[\(url)](\(url))" : "[\(name)](\(url))"
            if let tv = self.textView {
                tv.insertText(markdown, replacementRange: tv.selectedRange())
            } else {
                self.viewModel.content += markdown
            }
        }
    }

    // Open image file picker
    private func insertImage() {
        showTextMenu = false
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Insert Image"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            // Obsidian wiki-style — filename only, no full path
            let markdown = "![[\(url.lastPathComponent)]]"
            DispatchQueue.main.async {
                if let tv = self.textView {
                    tv.insertText(markdown, replacementRange: tv.selectedRange())
                } else {
                    self.viewModel.content += markdown
                }
            }
        }
    }

    // Wrap selected text in backticks `TEXT`
    private func wrapSelectionAsQuote() {
        showTextMenu = false
        guard let tv = textView else {
            viewModel.content += "`text`"
            return
        }
        let range = tv.selectedRange()
        if range.length > 0, let r = Range(range, in: tv.string) {
            let selected = String(tv.string[r])
            tv.insertText("`\(selected)`", replacementRange: range)
        } else {
            tv.insertText("`text`", replacementRange: range)
            tv.setSelectedRange(NSRange(location: range.location + 1, length: 4))
        }
    }

    // Open callout dialog
    private func insertCallout() {
        showTextMenu = false
        CalloutDialog.show { markdown in
            if let tv = self.textView {
                tv.insertText(markdown, replacementRange: tv.selectedRange())
            } else {
                self.viewModel.content += markdown
            }
        }
    }

    // Wrap selected text with prefix/suffix (e.g. **bold**)
    // If no selection, inserts placeholder text wrapped
    private func wrapSelection(prefix: String, suffix: String) {
        guard let tv = textView else {
            viewModel.content += "\(prefix)text\(suffix)"
            return
        }

        let range = tv.selectedRange()
        let content = tv.string

        if range.length > 0 {
            // Text is selected — wrap it
            if let swiftRange = Range(range, in: content) {
                let selected = String(content[swiftRange])
                tv.insertText("\(prefix)\(selected)\(suffix)", replacementRange: range)
            }
        } else {
            // No selection — insert placeholder and select the word
            let placeholder = "text"
            tv.insertText("\(prefix)\(placeholder)\(suffix)", replacementRange: range)
            // Move selection to highlight the placeholder word
            let newLocation = range.location + prefix.count
            tv.setSelectedRange(NSRange(location: newLocation, length: placeholder.count))
        }
    }

    // Open macOS native font panel
    private func showFontPicker() {
        showTextMenu = false
        let fontManager = NSFontManager.shared
        fontManager.target = FontChangeResponder.shared
        fontManager.action = #selector(FontChangeResponder.changeFont(_:))
        FontChangeResponder.shared.onFontChange = { font in
            viewModel.fontName = font.fontName
            viewModel.fontSize = font.pointSize
        }
        fontManager.orderFrontFontPanel(nil)
    }

    private func autoSave() {
        guard NoteWindowManager.shared.saveFolder != nil else { return }
        performSave()
    }

    private func performSave() {
        let title = viewModel.title.isEmpty ? "Untitled Note" : viewModel.title

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        let fullContent = """
---
Date: \(todayString)
---

# \(title)

\(viewModel.content)
"""
        NoteWindowManager.shared.saveNote(id: viewModel.id, title: title, content: fullContent)

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        lastSaved = "Saved \(timeFormatter.string(from: Date()))"
    }
}

// ============================================================
// SelectionAwareTextEditor
// ============================================================
// A custom NSViewRepresentable that wraps NSTextView so we
// can access the cursor position and selected text range —
// something SwiftUI's built-in TextEditor doesn't expose.
// ============================================================

struct SelectionAwareTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var onTextViewReady: (NSTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = ListContinuationTextView()
        let containerSize = CGSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer(containerSize: containerSize)
        container.widthTracksTextView = true
        let layoutManager = NSLayoutManager()
        let storage = NSTextStorage()
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = containerSize
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = NSSize(width: 4, height: 4)

        // No scroll bar — let the window resize handle overflow
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        DispatchQueue.main.async {
            onTextViewReady(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text actually changed (avoid cursor jumping)
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }

        textView.font = font
        textView.textColor = textColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectionAwareTextEditor

        init(_ parent: SelectionAwareTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

// ============================================================
// FontChangeResponder
// ============================================================
// macOS font panel requires an NSResponder to receive font
// change events. This singleton bridges the font panel back
// to our SwiftUI view.
// ============================================================

class FontChangeResponder: NSResponder {
    static let shared = FontChangeResponder()
    var onFontChange: ((NSFont) -> Void)?

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let manager = sender else { return }
        let newFont = manager.convert(NSFont.systemFont(ofSize: 13))
        onFontChange?(newFont)
    }
}

// ============================================================
// WindowAccessor — bridges SwiftUI to NSWindow
// ============================================================

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.callback(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.callback(nsView.window) }
    }
}
