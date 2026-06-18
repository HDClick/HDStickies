// ============================================================
// ListContinuationTextView.swift
// ============================================================
// Custom NSTextView that continues list formatting when
// the user presses Enter at the end of a list item.
//
// Supported:
//   "- "       → bullet list
//   "— "       → dashed list
//   "1. "      → numbered list (auto-increments)
//   "- [ ] "   → checklist
//   "- [x] "   → checked item (continues as unchecked)
// ============================================================

import AppKit

class ListContinuationTextView: NSTextView {

    override func insertNewline(_ sender: Any?) {
        guard let prefix = detectListPrefix() else {
            super.insertNewline(sender)
            return
        }

        // If the current line is empty (just the prefix), end the list
        if isCurrentLineOnlyPrefix(prefix) {
            removeCurrentLinePrefix(prefix)
            super.insertNewline(sender)
            return
        }

        // Insert newline then continue the list
        super.insertNewline(sender)
        insertText(prefix, replacementRange: selectedRange())
    }

    // --------------------------------------------------------
    // detectListPrefix()
    // Looks at the current line to find its list prefix
    // --------------------------------------------------------
    private func detectListPrefix() -> String? {
        guard let text = textStorage?.string else { return nil }
        let nsText = text as NSString
        let cursorPos = selectedRange().location
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))
        let line = nsText.substring(with: lineRange)

        // Numbered list — auto-increment the number
        if let match = line.range(of: #"^(\d+)\. "#, options: .regularExpression) {
            let numStr = String(line[match]).trimmingCharacters(in: .whitespaces)
                .components(separatedBy: ".").first ?? "1"
            let num = (Int(numStr) ?? 1) + 1
            return "\(num). "
        }

        // Checklist — continue as unchecked
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return "- [ ] " }
        if line.hasPrefix("- [ ] ") { return "- [ ] " }

        // Bullet
        if line.hasPrefix("- ") { return "- " }

        // Dashed
        if line.hasPrefix("— ") { return "— " }

        return nil
    }

    // --------------------------------------------------------
    // isCurrentLineOnlyPrefix()
    // True if the current line contains only the list prefix
    // (user pressed Enter on an empty list item — end the list)
    // --------------------------------------------------------
    private func isCurrentLineOnlyPrefix(_ prefix: String) -> Bool {
        guard let text = textStorage?.string else { return false }
        let nsText = text as NSString
        let cursorPos = selectedRange().location
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))
        let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
        return line == prefix.trimmingCharacters(in: .whitespaces) || line == prefix
    }

    // --------------------------------------------------------
    // removeCurrentLinePrefix()
    // Removes the list prefix from the current empty line
    // --------------------------------------------------------
    private func removeCurrentLinePrefix(_ prefix: String) {
        guard let text = textStorage?.string else { return }
        let nsText = text as NSString
        let cursorPos = selectedRange().location
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))

        // Delete the prefix characters on this line
        let deleteRange = NSRange(location: lineRange.location,
                                  length: min(prefix.count, lineRange.length))
        insertText("", replacementRange: deleteRange)
    }
}
