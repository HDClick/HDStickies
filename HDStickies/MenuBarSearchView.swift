// ============================================================
// MenuBarSearchView.swift
// ============================================================
// A quick search panel opened from the menu bar (⇧⌥⌘F).
// Scans all .md files in the save folder and shows live
// results as you type, with a content snippet preview.
// Click a result to open it in the All Notes editor.
// ============================================================

import SwiftUI
import AppKit

struct SearchResult: Identifiable {
    let id: String      // file path
    let url: URL
    let title: String
    let snippet: String // content preview around the match
    let color: NoteColor
    let date: String
}

struct MenuBarSearchView: View {

    var onDismiss: () -> Void

    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // ---- Search field ----
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Search all notes…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                    .onChange(of: query) { _ in performSearch() }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if isSearching {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // ---- Results ----
            if query.isEmpty {
                emptyPrompt
            } else if results.isEmpty && !isSearching {
                noResults
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { result in
                            resultRow(result)
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }

            Divider()

            // ---- Footer ----
            HStack {
                if let folder = NoteWindowManager.shared.saveFolder {
                    Text("Searching in \(folder.lastPathComponent)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("No save folder set — go to Settings")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("↩ to open · Esc to close")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
        }
    }

    // ---- Result row ----
    private func resultRow(_ result: SearchResult) -> some View {
        Button(action: { openResult(result) }) {
            HStack(spacing: 12) {

                // Colour stripe dot
                Circle()
                    .fill(result.color.background)
                    .frame(width: 10, height: 10)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title.isEmpty ? "Untitled Note" : result.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Highlighted snippet
                    Text(highlightedSnippet(result.snippet))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    if !result.date.isEmpty {
                        Text(result.date)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.001)) // hit area
    }

    // Strip markdown syntax for cleaner snippet display
    private func highlightedSnippet(_ text: String) -> String {
        // Find the query in the snippet and show context around it
        let clean = text
            .replacingOccurrences(of: "#+ ", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\*+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "~~|==|`", with: "", options: .regularExpression)
        return clean
    }

    // ---- Empty states ----
    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Type to search your notes")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No results for '\(query)'")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // --------------------------------------------------------
    // performSearch() — scans .md files for the query
    // --------------------------------------------------------
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }

        guard let folder = NoteWindowManager.shared.saveFolder else { return }

        isSearching = true
        let q = query.lowercased()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try FileManager.default
                    .contentsOfDirectory(at: folder,
                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [.skipsHiddenFiles])
                    .filter { $0.pathExtension == "md" }

                var found: [SearchResult] = []

                for url in files {
                    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }

                    let lower = raw.lowercased()
                    guard lower.contains(q) else { continue }

                    // Parse title, colour, date from YAML
                    var title = url.deletingPathExtension().lastPathComponent
                    var color: NoteColor = .red
                    var date = ""
                    var body = raw

                    if raw.hasPrefix("---") {
                        let lines = raw.components(separatedBy: "\n")
                        var endIdx = -1
                        for (i, line) in lines.enumerated() {
                            if i == 0 { continue }
                            let t = line.trimmingCharacters(in: .whitespaces)
                            if t == "---" { endIdx = i; break }
                            if t.lowercased().hasPrefix("color:") {
                                color = NoteColor(rawValue: t.replacingOccurrences(of: "color:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .red
                            }
                            if t.lowercased().hasPrefix("date:") {
                                date = t.replacingOccurrences(of: "date:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        if endIdx > 0 {
                            body = lines.dropFirst(endIdx + 1).joined(separator: "\n")
                        }
                    }

                    // Extract title from # heading
                    for line in body.components(separatedBy: "\n") {
                        let t = line.trimmingCharacters(in: .whitespaces)
                        if t.hasPrefix("# ") { title = String(t.dropFirst(2)); break }
                    }

                    // Build snippet — 120 chars around first match
                    let snippet: String
                    if let range = lower.range(of: q) {
                        let start = max(lower.startIndex, lower.index(range.lowerBound, offsetBy: -40, limitedBy: lower.startIndex) ?? lower.startIndex)
                        let end   = min(lower.endIndex, lower.index(range.upperBound, offsetBy: 80, limitedBy: lower.endIndex) ?? lower.endIndex)
                        snippet = "…" + String(raw[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
                    } else {
                        snippet = String(body.prefix(120))
                    }

                    found.append(SearchResult(
                        id: url.path, url: url,
                        title: title, snippet: snippet,
                        color: color, date: date
                    ))
                }

                // Sort by modification date
                let sorted = found.sorted {
                    let a = (try? $0.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    let b = (try? $1.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    return a > b
                }

                DispatchQueue.main.async {
                    self.results = sorted
                    self.isSearching = false
                }
            } catch {
                DispatchQueue.main.async { self.isSearching = false }
            }
        }
    }

    // --------------------------------------------------------
    private func openResult(_ result: SearchResult) {
        let path = result.url.path

        // 1. Open All Notes window via shared MenuBarManager
        if let manager = MenuBarManager.shared {
            manager.openAllNotes()
        } else {
        }

        // 2. Close search panel
        onDismiss()

        // 3. Store path on ViewModel directly (works even before view appears)
        // AND post notification for when view is already active
        if let manager = MenuBarManager.shared {
            manager.allNotesViewModel.pendingSelectPath = path
        }
        // Also post notification with longer delay for safety
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NotificationCenter.default.post(
                name: .openNoteInEditor,
                object: nil,
                userInfo: ["path": path]
            )
        }
    }
}
