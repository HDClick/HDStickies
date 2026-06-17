// ============================================================
// ExportManager.swift
// ============================================================
// Export all HDStickies notes as a bundle.
//
// Options:
// 1. Export as ZIP — all .md files zipped into HDStickies-Export.zip
// 2. Export to folder — copies all .md files to a chosen folder
// 3. Export index — creates a single INDEX.md listing all notes
//    with links, great for Obsidian dashboards
// ============================================================

import Foundation
import AppKit
import SwiftUI

class ExportManager {

    static let shared = ExportManager()

    // --------------------------------------------------------
    // exportAsZip() — zips all .md files
    // --------------------------------------------------------
    func exportAsZip() {
        guard let folder = NoteWindowManager.shared.saveFolder else {
            showAlert(title: "No Save Folder", message: "Set a save folder in Settings first.")
            return
        }

        // Ask where to save the zip
        let save = NSSavePanel()
        save.allowedContentTypes = [.zip]
        save.nameFieldStringValue = "HDStickies-Export.zip"
        save.prompt = "Export"
        save.message = "Choose where to save the export bundle"

        guard save.runModal() == .OK, let destURL = save.url else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try FileManager.default
                    .contentsOfDirectory(at: folder,
                                         includingPropertiesForKeys: nil,
                                         options: [.skipsHiddenFiles])
                    .filter { $0.pathExtension == "md" }

                // Create a temp directory to zip from
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("HDStickies-Export-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

                for file in files {
                    let dest = tmp.appendingPathComponent(file.lastPathComponent)
                    try FileManager.default.copyItem(at: file, to: dest)
                }

                // Remove existing zip if present
                try? FileManager.default.removeItem(at: destURL)

                // Zip using Process (shell zip command)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.arguments = ["-r", destURL.path, "."]
                process.currentDirectoryURL = tmp
                try process.run()
                process.waitUntilExit()

                // Clean up temp dir
                try? FileManager.default.removeItem(at: tmp)

                DispatchQueue.main.async {
                    self.showSuccessAlert(
                        title: "Export Complete",
                        message: "\(files.count) note\(files.count == 1 ? "" : "s") exported to \(destURL.lastPathComponent)",
                        url: destURL
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // --------------------------------------------------------
    // exportToFolder() — copies all .md files to chosen folder
    // --------------------------------------------------------
    func exportToFolder() {
        guard let sourceFolder = NoteWindowManager.shared.saveFolder else {
            showAlert(title: "No Save Folder", message: "Set a save folder in Settings first.")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to copy your notes into"

        guard panel.runModal() == .OK, let destFolder = panel.url else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try FileManager.default
                    .contentsOfDirectory(at: sourceFolder,
                                         includingPropertiesForKeys: nil,
                                         options: [.skipsHiddenFiles])
                    .filter { $0.pathExtension == "md" }

                var exported = 0
                for file in files {
                    let dest = destFolder.appendingPathComponent(file.lastPathComponent)
                    // Overwrite if exists
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.copyItem(at: file, to: dest)
                    exported += 1
                }

                DispatchQueue.main.async {
                    self.showSuccessAlert(
                        title: "Export Complete",
                        message: "\(exported) note\(exported == 1 ? "" : "s") copied to \(destFolder.lastPathComponent)",
                        url: destFolder
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // --------------------------------------------------------
    // exportIndex() — creates a INDEX.md dashboard file
    // --------------------------------------------------------
    func exportIndex() {
        guard let folder = NoteWindowManager.shared.saveFolder else {
            showAlert(title: "No Save Folder", message: "Set a save folder in Settings first.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try FileManager.default
                    .contentsOfDirectory(at: folder,
                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [.skipsHiddenFiles])
                    .filter { $0.pathExtension == "md" && $0.lastPathComponent != "INDEX.md" }
                    .sorted {
                        let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        return a > b
                    }

                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let today = df.string(from: Date())

                var lines = [
                    "---",
                    "Date: \(today)",
                    "Tags: HDStickies, Index",
                    "---",
                    "",
                    "# HDStickies Index",
                    "",
                    "> [!note] Auto-generated by HDStickies",
                    "> This index lists all your HDStickies notes.",
                    "",
                    "## Notes (\(files.count))",
                    ""
                ]

                for file in files {
                    // Extract title from # heading for wiki link display name
                    var displayTitle = file.deletingPathExtension().lastPathComponent
                    if let raw = try? String(contentsOf: file, encoding: .utf8) {
                        for line in raw.components(separatedBy: "\n") {
                            let t = line.trimmingCharacters(in: .whitespaces)
                            if t.hasPrefix("# ") { displayTitle = String(t.dropFirst(2)); break }
                        }
                    }
                    // Obsidian wiki link
                    lines.append("- [[\(file.deletingPathExtension().lastPathComponent)|\(displayTitle)]]")
                }

                let indexContent = lines.joined(separator: "\n")
                let indexURL = folder.appendingPathComponent("HDStickies-INDEX.md")
                try indexContent.write(to: indexURL, atomically: true, encoding: .utf8)

                DispatchQueue.main.async {
                    self.showSuccessAlert(
                        title: "Index Created",
                        message: "HDStickies-INDEX.md created with \(files.count) links — open in Obsidian to see your dashboard",
                        url: indexURL
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // --------------------------------------------------------
    // Helpers
    // --------------------------------------------------------
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showSuccessAlert(title: String, message: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "Done")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
}
