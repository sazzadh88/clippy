import AppKit
import ApplicationServices

/// Finds the text caret in the frontmost app and pastes into it. Both need Accessibility permission.
@MainActor
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to System Settings › Privacy & Security › Accessibility.
    static func requestTrust() {
        // Value of kAXTrustedCheckOptionPrompt; the global itself isn't concurrency-safe under Swift 6.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Where the text caret is in the frontmost app, in Cocoa screen coordinates. Tries, in order:
    /// the caret itself, the character just before it, then the focused text field's frame.
    /// Nil when not trusted or nothing plausible is exposed (the caller falls back to the mouse).
    static func caretRect() -> CGRect? {
        guard isTrusted, let primary = NSScreen.screens.first,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              // Ask the app directly: Chromium browsers don't answer the system-wide element.
              let element: AXUIElement = copy(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute)
        else { return nil }

        var candidates: [CGRect] = []
        if let rangeValue: AXValue = copy(element, kAXSelectedTextRangeAttribute) {
            var range = CFRange()
            AXValueGetValue(rangeValue, .cfRange, &range)
            if let caret = bounds(of: range, in: element) { candidates.append(caret) }
            // Terminal and others report a placeholder for an empty range but real glyph rects:
            // the caret sits at the right edge of the previous character.
            if range.location > 0, let glyph = bounds(of: CFRange(location: range.location - 1, length: 1), in: element) {
                candidates.append(CGRect(x: glyph.maxX, y: glyph.minY, width: 0, height: glyph.height))
            }
        }
        if let position: AXValue = copy(element, kAXPositionAttribute), let size: AXValue = copy(element, kAXSizeAttribute) {
            var origin = CGPoint.zero, extent = CGSize.zero
            AXValueGetValue(position, .cgPoint, &origin)
            AXValueGetValue(size, .cgSize, &extent)
            candidates.append(CGRect(origin: origin, size: extent)) // field-sized only; see isPlausibleCaret
        }

        return candidates.lazy
            .filter(isPlausibleCaret)
            .map { cocoaRect(fromAX: $0, primaryScreenHeight: primary.frame.height) }
            .first { rect in NSScreen.screens.contains { $0.frame.contains(CGPoint(x: rect.minX, y: rect.midY)) } }
    }

    /// Apps report placeholders like (0, 1440, 0, 0) for "unknown"; a real caret or single-line
    /// field has a line-ish height. Also rejects whole text views (Terminal's spans the scrollback).
    nonisolated static func isPlausibleCaret(_ rect: CGRect) -> Bool {
        rect.height > 0 && rect.height <= 120
    }

    private static func bounds(of range: CFRange, in element: AXUIElement) -> CGRect? {
        var range = range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         rangeValue, &result) == .success,
              let result, CFGetTypeID(result) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(result as! AXValue, .cgRect, &rect) ? rect : nil
    }

    /// Typed AX attribute read; nil on failure or type mismatch.
    private static func copy<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    /// AX uses a top-left origin at the primary screen; Cocoa uses bottom-left.
    nonisolated static func cocoaRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Sends ⌘V to whichever window has keyboard focus.
    /// ponytail: key code 9 is V on QWERTY-family layouts; map via the current keyboard layout if Dvorak users report it.
    static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
