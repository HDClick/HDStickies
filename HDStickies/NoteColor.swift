// ============================================================
// NoteColor.swift
// ============================================================
// Defines the colour options for sticky notes.
// In Delphi you might use a TColor constant — here we use
// a Swift "enum" which is a clean way to define a set of
// named options with associated values.
// ============================================================

import SwiftUI

// The available note background colours
enum NoteColor: String, CaseIterable, Identifiable {
    case yellow  = "yellow"
    case orange  = "orange"
    case green   = "green"
    case blue    = "blue"
    case pink    = "pink"
    case purple  = "purple"
    case white   = "white"
    case dark    = "dark"

    // Identifiable conformance — needed for SwiftUI lists/pickers
    var id: String { self.rawValue }

    // --------------------------------------------------------
    // background — the main fill colour of the note
    // --------------------------------------------------------
    var background: Color {
        switch self {
        case .yellow:  return Color(red: 1.0,  green: 0.96, blue: 0.60)  // Warm yellow
        case .orange:  return Color(red: 1.0,  green: 0.82, blue: 0.55)  // Soft orange
        case .green:   return Color(red: 0.75, green: 0.95, blue: 0.70)  // Mint green
        case .blue:    return Color(red: 0.65, green: 0.85, blue: 1.0)   // Sky blue
        case .pink:    return Color(red: 1.0,  green: 0.75, blue: 0.85)  // Soft pink
        case .purple:  return Color(red: 0.85, green: 0.75, blue: 1.0)   // Lavender
        case .white:   return Color(red: 0.98, green: 0.98, blue: 0.98)  // Off white
        case .dark:    return Color(red: 0.18, green: 0.18, blue: 0.22)  // Dark slate
        }
    }

    // --------------------------------------------------------
    // textColor — text colour that contrasts with the background
    // Dark note gets light text, all others get dark text
    // --------------------------------------------------------
    var textColor: Color {
        switch self {
        case .dark:    return Color(red: 0.92, green: 0.92, blue: 0.95)  // Light text
        default:       return Color(red: 0.15, green: 0.15, blue: 0.18)  // Dark text
        }
    }

    // --------------------------------------------------------
    // toolbarColor — slightly darker/lighter than background
    // Used for the toolbar strip at the top of the note
    // --------------------------------------------------------
    var toolbarColor: Color {
        switch self {
        case .dark:    return Color(red: 0.12, green: 0.12, blue: 0.16)
        default:       return background.opacity(0.7)
        }
    }

    // --------------------------------------------------------
    // accentColor — used for button highlights and icons
    // --------------------------------------------------------
    var accentColor: Color {
        switch self {
        case .dark:    return Color(red: 0.95, green: 0.85, blue: 0.40)  // Gold on dark
        default:       return Color(red: 0.20, green: 0.20, blue: 0.25).opacity(0.6)
        }
    }

    // --------------------------------------------------------
    // emoji — shown in the colour picker for each option
    // --------------------------------------------------------
    var emoji: String {
        switch self {
        case .yellow:  return "🟡"
        case .orange:  return "🟠"
        case .green:   return "🟢"
        case .blue:    return "🔵"
        case .pink:    return "🩷"
        case .purple:  return "🟣"
        case .white:   return "⚪"
        case .dark:    return "⚫"
        }
    }
}
