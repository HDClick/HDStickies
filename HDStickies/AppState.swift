// ============================================================
// AppState.swift
// ============================================================
import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var pendingNotePath: String? = nil
}

// Notification fired when search wants to open a specific note
extension Notification.Name {
    static let openNoteInEditor = Notification.Name("HDStickies_OpenNoteInEditor")
}
