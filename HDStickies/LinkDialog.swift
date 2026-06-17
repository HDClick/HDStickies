// ============================================================
// LinkDialog.swift
// ============================================================
// Shows a floating NSPanel for link insertion.
// Using NSPanel directly rather than SwiftUI .sheet because
// our All Notes window uses a custom window level and SwiftUI
// sheets don't always attach correctly in that context.
//
// Call LinkDialog.show() to present it.
// The onInsert callback fires with (name, url) when Done is tapped.
// ============================================================

import AppKit
import SwiftUI

class LinkDialog: NSObject {

    // The panel window
    private static var panel: NSPanel?

    // --------------------------------------------------------
    // show() — presents the link dialog as a floating panel
    // --------------------------------------------------------
    static func show(onInsert: @escaping (String, String) -> Void) {
        // Close any existing panel first
        panel?.close()
        panel = nil

        let view = LinkDialogView(onInsert: { name, url in
            onInsert(name, url)
            panel?.close()
            panel = nil
        }, onCancel: {
            panel?.close()
            panel = nil
        })

        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 380, height: 220)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
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

        // Float above the All Notes window
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
        p.center()
        p.makeKeyAndOrderFront(nil)

        panel = p
    }
}

// ============================================================
// LinkDialogView — the SwiftUI content inside the panel
// ============================================================
struct LinkDialogView: View {

    var onInsert: (String, String) -> Void
    var onCancel: () -> Void

    @State private var linkName: String = ""
    @State private var linkURL: String  = ""
    @FocusState private var focused: Field?
    enum Field { case name, url }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Title
            Text("Insert Link")
                .font(.system(size: 16, weight: .bold))

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                TextField("Display text (optional)", text: $linkName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(focused == .name
                                ? Color.accentColor
                                : Color(NSColor.separatorColor), lineWidth: 1.5))
                    .focused($focused, equals: .name)
                    .onSubmit { focused = .url }
            }

            // URL field
            VStack(alignment: .leading, spacing: 6) {
                Text("Link to:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                TextField("Enter a URL", text: $linkURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(focused == .url
                                ? Color.accentColor
                                : Color(NSColor.separatorColor), lineWidth: 1.5))
                    .focused($focused, equals: .url)
                    .onSubmit { insertAndClose() }
            }

            // Buttons
            HStack {
                Spacer()

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Done") { insertAndClose() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(linkURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focused = .name
            }
        }
    }

    private func insertAndClose() {
        let url = linkURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        onInsert(linkName, url)
    }
}
