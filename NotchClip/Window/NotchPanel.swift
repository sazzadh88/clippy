import AppKit

final class NotchPanel: NSPanel {
    /// Only true while expanded, so hovering never steals focus.
    var allowsKey = false

    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true // toggled per cursor position (click-through)
    }

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}
