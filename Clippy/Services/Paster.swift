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

    /// Caret (or selection) rect of the focused text element, in Cocoa screen coordinates.
    /// Nil when not trusted or the app doesn't expose it (common in Electron apps and some browsers).
    static func caretRect() -> CGRect? {
        guard isTrusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
              let range else { return nil }
        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         range, &bounds) == .success,
              let bounds, CFGetTypeID(bounds) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect), rect != .zero,
              let primary = NSScreen.screens.first else { return nil }

        let cocoa = cocoaRect(fromAX: rect, primaryScreenHeight: primary.frame.height)
        // Some apps report garbage; only trust a rect that lands on a screen.
        return NSScreen.screens.contains { $0.frame.intersects(cocoa) } ? cocoa : nil
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
