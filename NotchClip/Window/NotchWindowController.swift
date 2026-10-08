import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .option]))
}

/// Hosting view that takes the first click even though the panel is never active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchWindowController {
    /// Room around the max panel for ears and glow.
    static let margin: CGFloat = 24
    static let leaveDelay: Duration = .milliseconds(400)

    let panel = NotchPanel()
    let model: NotchViewModel
    private var monitors: [Any] = []
    private var leaveTask: Task<Void, Never>?
    /// The leave-to-collapse timer only arms once the cursor has been inside the expanded panel,
    /// so opening via the hotkey with the mouse elsewhere doesn't instantly collapse.
    private var cursorEnteredSinceExpand = false

    init(store: ClipboardStore, monitor: PasteboardMonitor) {
        model = NotchViewModel(store: store, monitor: monitor)
        let root = NotchRootView(model: model)
            .environment(model)
            .environment(store)
            .environment(monitor)
        let host = FirstMouseHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host
        model.onStateChange = { [weak self] in self?.stateChanged($0) }
        reposition()
        panel.orderFrontRegardless()
        installMonitors()
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in self?.toggle() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    func reposition() {
        guard let screen = NSScreen.notchScreen else { return }
        let geometry = NotchGeometry.of(screen)
        model.geometry = geometry
        let size = CGSize(width: NotchViewModel.expandedSize.width + Self.margin * 2,
                          height: NotchViewModel.expandedSize.height + Self.margin)
        let origin = CGPoint(x: screen.frame.minX + geometry.centerX - size.width / 2,
                             y: screen.frame.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    func toggle() {
        model.state == .expanded ? model.collapse() : model.expand()
    }

    // MARK: - Mouse tracking & click-through

    private func installMonitors() {
        // Global monitors see events going to other apps (no Accessibility permission needed for mouse);
        // local monitors see events going to our own panel.
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover() }
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateHover() }
            return event
        }) { monitors.append(m) }

        // A click that reaches another app means the user clicked outside the panel.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.model.collapse() }
        }) { monitors.append(m) }

        // Keys reach the panel only while it's key (expanded). Handled here, before the search field sees them.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let keyCode = event.keyCode
            let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            let digit = event.charactersIgnoringModifiers.flatMap(Int.init)
            let handled = MainActor.assumeIsolated {
                self?.handleKey(keyCode, command: command, digit: digit) ?? false
            }
            return handled ? nil : event
        }) { monitors.append(m) }
    }

    /// Returns true if the key was consumed.
    private func handleKey(_ keyCode: UInt16, command: Bool, digit: Int?) -> Bool {
        guard model.state == .expanded else { return false }
        switch keyCode {
        case 53: model.collapse() // Esc
        case 125: model.moveSelection(by: 1) // ↓
        case 126: model.moveSelection(by: -1) // ↑
        case 36, 76: model.copySelected() // Return, keypad Enter
        case 51 where !model.searchFocused: model.deleteSelected() // ⌫ (in the field it edits text)
        case 3 where command: model.showSearch() // ⌘F
        default:
            guard command, let digit, (1...9).contains(digit) else { return false }
            model.quickCopy(digit) // ⌘1…⌘9
        }
        return true
    }

    /// Visible shape in screen coordinates for a given state.
    private func visibleRect(for state: NotchState) -> CGRect {
        let m = model.metrics(for: state)
        let frame = panel.frame
        return CGRect(x: frame.midX - m.outerWidth / 2, y: frame.maxY - m.height,
                      width: m.outerWidth, height: m.height)
    }

    private func updateHover() {
        let cursor = NSEvent.mouseLocation
        // Hysteresis: enter via the notch, leave via the larger hovered/expanded shape.
        let inside = visibleRect(for: model.state).insetBy(dx: -1, dy: -1).contains(cursor)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }

        switch model.state {
        case .collapsed:
            if inside { model.hover() }
        case .hovered:
            if !inside { model.unhover() }
        case .expanded:
            if inside {
                cursorEnteredSinceExpand = true
                leaveTask?.cancel()
                leaveTask = nil
            } else if leaveTask == nil, cursorEnteredSinceExpand {
                leaveTask = Task { [weak self] in
                    try? await Task.sleep(for: Self.leaveDelay)
                    guard !Task.isCancelled else { return }
                    self?.model.collapse()
                }
            }
        }
    }

    private func stateChanged(_ state: NotchState) {
        leaveTask?.cancel()
        leaveTask = nil
        cursorEnteredSinceExpand = false
        switch state {
        case .expanded:
            panel.allowsKey = true
            panel.makeKey()
        case .collapsed, .hovered:
            if panel.isKeyWindow { panel.resignKey() }
            panel.allowsKey = false
        }
        updateHover()
    }
}
