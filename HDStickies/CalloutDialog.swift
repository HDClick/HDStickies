// ============================================================
// CalloutDialog.swift
// ============================================================
// Obsidian-style callout insertion dialog.
// Presented as a floating NSPanel — same approach as LinkDialog.
//
// Inserts markdown like:
// > [!note] Optional Title
// > Content here
// ============================================================

import AppKit
import SwiftUI

class CalloutDialog: NSObject {

    private static var panel: NSPanel?

    static func show(onInsert: @escaping (String) -> Void) {
        panel?.close()
        panel = nil

        let view = CalloutDialogView(
            onInsert: { markdown in
                onInsert(markdown)
                panel?.close()
                panel = nil
            },
            onCancel: {
                panel?.close()
                panel = nil
            }
        )

        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 520, height: 420)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.contentViewController = hosting
        p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
        p.center()
        p.makeKeyAndOrderFront(nil)
        panel = p
    }
}

// ============================================================
// Callout types — matches Obsidian's full list
// ============================================================
struct CalloutType: Identifiable, Hashable {
    let id: String      // the markdown keyword e.g. "note"
    let label: String   // display name e.g. "Note"
    let emoji: String   // visual hint

    static let all: [CalloutType] = [
        // Default group
        .init(id: "note",      label: "Note",               emoji: "📝"),
        .init(id: "abstract",  label: "Abstract",           emoji: "📋"),
        .init(id: "summary",   label: "Abstract (summary)", emoji: "📋"),
        .init(id: "tldr",      label: "Abstract (tldr)",    emoji: "📋"),
        .init(id: "info",      label: "Info",               emoji: "ℹ️"),
        .init(id: "todo",      label: "Todo",               emoji: "✅"),
        .init(id: "important", label: "Important",          emoji: "❗"),
        .init(id: "tip",       label: "Tip",                emoji: "💡"),
        .init(id: "hint",      label: "Tip (hint)",         emoji: "💡"),
        .init(id: "success",   label: "Success",            emoji: "✅"),
        .init(id: "check",     label: "Success (check)",    emoji: "✅"),
        .init(id: "done",      label: "Success (done)",     emoji: "✅"),
        .init(id: "question",  label: "Question",           emoji: "❓"),
        .init(id: "help",      label: "Question (help)",    emoji: "❓"),
        .init(id: "faq",       label: "Question (faq)",     emoji: "❓"),
        .init(id: "warning",   label: "Warning",            emoji: "⚠️"),
        .init(id: "caution",   label: "Warning (caution)",  emoji: "⚠️"),
        .init(id: "attention", label: "Warning (attention)", emoji: "⚠️"),
        .init(id: "failure",   label: "Failure",            emoji: "❌"),
        .init(id: "fail",      label: "Failure (fail)",     emoji: "❌"),
        .init(id: "missing",   label: "Failure (missing)",  emoji: "❌"),
        .init(id: "danger",    label: "Danger",             emoji: "🔴"),
        .init(id: "error",     label: "Danger (error)",     emoji: "🔴"),
        .init(id: "bug",       label: "Bug",                emoji: "🐛"),
        .init(id: "example",   label: "Example",            emoji: "📌"),
        .init(id: "quote",     label: "Quote",              emoji: "💬"),
        .init(id: "cite",      label: "Quote (cite)",       emoji: "💬"),
    ]
}

enum CollapseState: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case open      = "Open"
    case closed    = "Closed"
    var id: String { rawValue }

    // The markdown suffix: nothing, +, or -
    var suffix: String {
        switch self {
        case .default: return ""
        case .open:    return "+"
        case .closed:  return "-"
        }
    }
}

// ============================================================
// CalloutDialogView
// ============================================================
struct CalloutDialogView: View {

    var onInsert: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedType: CalloutType = CalloutType.all[0]
    @State private var title: String        = ""
    @State private var collapseState: CollapseState = .default
    @State private var content: String      = ""
    @FocusState private var contentFocused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // ---- Header ----
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Callout Type")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                // Type picker dropdown
                Picker("", selection: $selectedType) {
                    Text("---- Default ----").disabled(true)
                    ForEach(CalloutType.all) { type in
                        Text("\(type.emoji)  \(type.label)").tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // ---- Title ----
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Optional, leave blank for default title")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                TextField("Input title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    .frame(width: 240)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // ---- Collapse State ----
            HStack {
                Text("Collapse State")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("", selection: $collapseState) {
                    ForEach(CollapseState.allCases) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // ---- Content ----
            HStack(alignment: .top, spacing: 16) {
                Text("Content")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.top, 4)

                TextEditor(text: $content)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    .frame(height: 110)
                    .focused($contentFocused)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // ---- Shortcut hint ----
            HStack {
                Spacer()
                Text("⌘ + Enter to insert")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            // ---- Buttons ----
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Insert") { insertCallout() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 520)
    }

    private func insertCallout() {
        // Build the Obsidian callout markdown
        // Format: > [!type+/-] Optional Title
        //         > Content
        let typePart  = "[!\(selectedType.id)]\(collapseState.suffix)"
        let titlePart = title.isEmpty ? "" : " \(title)"
        let header    = "> \(typePart)\(titlePart)"

        // Prefix each content line with "> "
        let contentLines = content.isEmpty
            ? ["> "]
            : content.components(separatedBy: "\n").map { "> \($0)" }

        let markdown = "\n" + ([header] + contentLines).joined(separator: "\n") + "\n"
        onInsert(markdown)
    }
}
