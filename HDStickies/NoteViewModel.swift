// ============================================================
// NoteViewModel.swift
// ============================================================
// Holds all the STATE for a single note.
// By separating state into a ViewModel (ObservableObject),
// both NoteView (SwiftUI) and NoteWindowController (AppKit)
// can read and write the same data.
//
// In Delphi terms: like a data module shared between a form
// and the main application.
//
// @Published means: "when this value changes, update the UI"
// ============================================================

import SwiftUI
import Combine

class NoteViewModel: ObservableObject, Identifiable {

    let id: String

    @Published var noteColor: NoteColor
    @Published var title: String
    @Published var content: String
    @Published var isCollapsed: Bool
    @Published var fontName: String
    @Published var fontSize: Double

    init(id: String, color: NoteColor, title: String, content: String,
         isCollapsed: Bool, fontName: String, fontSize: Double) {
        self.id = id
        self.noteColor = color
        self.title = title
        self.content = content
        self.isCollapsed = isCollapsed
        self.fontName = fontName
        self.fontSize = fontSize
    }

    // Resolved font — used by the text editor
    var resolvedFont: Font {
        if fontName == "System" {
            return .system(size: fontSize)
        }
        return .custom(fontName, size: fontSize)
    }

    var resolvedNSFont: NSFont {
        if fontName == "System" {
            return NSFont.systemFont(ofSize: fontSize)
        }
        return NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }
}
