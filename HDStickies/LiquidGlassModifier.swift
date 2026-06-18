// ============================================================
// LiquidGlassModifier.swift
// ============================================================
// Applies Apple's Liquid Glass effect to floating notes.
// Uses RoundedRectangle shape to match the note corners.
// ============================================================

import SwiftUI

struct LiquidGlassModifier: ViewModifier {

    let enabled: Bool
    let fallbackColor: Color

    func body(content: Content) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                content
                    .background(
                        // Tint the glass with the note colour at low opacity
                        // so you still get a colour hint while seeing through
                        RoundedRectangle(cornerRadius: 16)
                            .fill(fallbackColor.opacity(0.25))
                    )
                    .glassEffect(
                        .regular,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(fallbackColor)
                    )
            }
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(fallbackColor)
                )
        }
    }
}
