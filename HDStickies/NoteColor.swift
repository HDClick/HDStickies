// ============================================================
// NoteColor.swift
// ============================================================
// v5 — clean solid colours: Red, Green, Blue, Yellow,
// Orange, Purple, Gray. Simple names, rich solid tones.
// ============================================================

import SwiftUI

enum NoteColor: String, CaseIterable, Identifiable {
    case red    = "red"
    case green  = "green"
    case blue   = "blue"
    case yellow = "yellow"
    case orange = "orange"
    case purple = "purple"
    case gray   = "gray"

    var id: String { rawValue }

    var background: Color {
        switch self {
        case .red:    return Color(red: 0.55, green: 0.07, blue: 0.09)
        case .green:  return Color(red: 0.08, green: 0.30, blue: 0.15)
        case .blue:   return Color(red: 0.05, green: 0.22, blue: 0.42)
        case .yellow: return Color(red: 0.50, green: 0.38, blue: 0.02)
        case .orange: return Color(red: 0.55, green: 0.25, blue: 0.02)
        case .purple: return Color(red: 0.28, green: 0.08, blue: 0.38)
        case .gray:   return Color(red: 0.20, green: 0.20, blue: 0.22)
        }
    }

    var textColor: Color {
        Color(red: 0.93, green: 0.93, blue: 0.95)
    }

    var toolbarColor: Color {
        background.opacity(0.8)
    }

    var accentColor: Color {
        switch self {
        case .red:    return Color(red: 1.0,  green: 0.60, blue: 0.60)
        case .green:  return Color(red: 0.60, green: 1.0,  blue: 0.70)
        case .blue:   return Color(red: 0.50, green: 0.85, blue: 1.0)
        case .yellow: return Color(red: 1.0,  green: 0.90, blue: 0.40)
        case .orange: return Color(red: 1.0,  green: 0.75, blue: 0.40)
        case .purple: return Color(red: 0.85, green: 0.60, blue: 1.0)
        case .gray:   return Color(red: 0.85, green: 0.85, blue: 0.85)
        }
    }

    var displayName: String {
        switch self {
        case .red:    return "Red"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .gray:   return "Gray"
        }
    }

    var emoji: String {
        switch self {
        case .red:    return "🔴"
        case .green:  return "🟢"
        case .blue:   return "🔵"
        case .yellow: return "🟡"
        case .orange: return "🟠"
        case .purple: return "🟣"
        case .gray:   return "⚫"
        }
    }
}
