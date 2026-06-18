import AppKit
import SwiftUI

// ============================================================
// WindowDragController
// Monitors raw NSEvents for the window.
// Drag only starts in top 44pts of the window.
// Uses per-event delta from event.deltaX/deltaY — no
// coordinate conversion needed, always smooth.
// ============================================================

class WindowDragController: NSObject {

    private weak var window: NSWindow?
    private var isDragging = false
    private let stripHeight: CGFloat = 44

    init(window: NSWindow) {
        self.window = window
        super.init()
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        guard let window = window else { return }

        switch event.type {
        case .leftMouseDown:
            // event.locationInWindow: y=0 at BOTTOM, so top strip = high y
            let y = event.locationInWindow.y
            let h = window.frame.height
            isDragging = (y >= h - stripHeight)

        case .leftMouseDragged:
            guard isDragging else { return }
            // event.deltaX/deltaY give per-event movement in points
            // deltaY is already flipped for screen coordinates
            window.setFrameOrigin(NSPoint(
                x: window.frame.origin.x + event.deltaX,
                y: window.frame.origin.y - event.deltaY
            ))

        case .leftMouseUp:
            isDragging = false

        default: break
        }
    }
}

// ============================================================
// HoverDragStrip — visual only, appears near top edge
// Only shows when mouse is within 44pts of the top
// ============================================================

struct HoverDragStrip: View {
    @State private var isHovering = false

    var body: some View {
        // Fixed size pill — sits in the centre gap between button groups
        // Only 44pt wide, 16pt tall — tight hover area
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(isHovering ? 0.18 : 0))
                .animation(.easeInOut(duration: 0.12), value: isHovering)

            if isHovering {
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.60))
                            .frame(width: 10, height: 3)
                    }
                }
            }
        }
        .frame(width: 44, height: 16)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
