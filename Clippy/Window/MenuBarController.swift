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

/// Owns the menu bar icon, the dropdown under it, and the ⌥⌘V popup at the text caret.
@MainActor
final class MenuBarController: NSObject {
    let model: PanelModel
    private let panel = MenuBarPanel()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var monitors: [Any] = []
    /// Where the hotkey popup should appear (caret or mouse); nil means under the menu bar icon.
    private var popupAnchor: CGRect?

    init(store: ClipboardStore, monitor: PasteboardMonitor, settings: AppSettings) {
        model = PanelModel(store: store, monitor: monitor, settings: settings)
        super.init()

        let root = PanelView()
            .environment(model)
            .environment(store)
            .environment(monitor)
        let host = FirstMouseHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host
        panel.setContentSize(PanelModel.size)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clippy")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.onOpenChange = { [weak self] in self?.openChanged($0) }
        model.onPaste = { [weak self] in self?.paste() }
        installMonitors()
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in self?.togglePopupAtCaret() }
    }

    // MARK: - Hotkey popup

    /// ⌥⌘V: open next to the text caret (or the mouse, if the app doesn't expose its caret),
    /// in paste mode: choosing an item pastes it into that app.
    private func togglePopupAtCaret() {
        guard !model.isOpen else { return model.close() }
        let mouse = NSEvent.mouseLocation
        popupAnchor = Paster.caretRect() ?? CGRect(origin: mouse, size: .zero)
        model.open(pastesOnSelect: true)
    }

    private func paste() {
        // Hide at once so keyboard focus is back in the target app before ⌘V arrives.
        panel.orderOut(nil)
        guard Paster.isTrusted else { return Paster.requestTrust() } // item is still copied
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            Paster.pressCommandV()
        }
    }

    /// Below the anchor, left-aligned with it; above it when there's no room below. Kept on screen.
    nonisolated static func popupOrigin(anchor: CGRect, size: CGSize, visible: CGRect) -> CGPoint {
        let gap: CGFloat = 6
        var y = anchor.minY - gap - size.height
        if y < visible.minY { y = anchor.maxY + gap }
        y = min(max(y, visible.minY), visible.maxY - size.height)
        let x = min(max(anchor.minX, visible.minX + 8), visible.maxX - size.width - 8)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Menu bar icon

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            model.toggle()
        }
    }

    private func showMenu() {
        model.close()
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // Attaching the menu only for this click keeps left-click free to toggle the panel.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() { model.openSettings() }

    // MARK: - Panel

    private func openChanged(_ isOpen: Bool) {
        if isOpen {
            if let anchor = popupAnchor {
                let point = CGPoint(x: anchor.midX, y: anchor.midY)
                let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
                if let visible = screen?.visibleFrame {
                    panel.setFrameOrigin(Self.popupOrigin(anchor: anchor, size: PanelModel.size, visible: visible))
                }
                popupAnchor = nil
            } else {
                statusItem.button?.highlight(true)
                positionPanel()
            }
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            panel.makeKey()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Motion.reduceMotion ? 0 : 0.12
                panel.animator().alphaValue = 1
            }
        } else {
            statusItem.button?.highlight(false)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Motion.reduceMotion ? 0 : 0.1
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self, !self.model.isOpen else { return }
                    self.panel.orderOut(nil)
                }
            })
        }
    }

    /// Frame of the menu bar icon in screen coordinates, if it's showing.
    private var iconFrame: CGRect? {
        guard let window = statusItem.button?.window, window.occlusionState.contains(.visible) else { return nil }
        return window.frame
    }

    /// On the display with the mouse: under the menu bar icon if it's on that display, otherwise
    /// top-right (the icon can be hidden, e.g. crowded out by the notch, or the hotkey was used).
    private func positionPanel() {
        let size = PanelModel.size
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        let icon = iconFrame.flatMap { screen.frame.contains(CGPoint(x: $0.midX, y: $0.midY)) ? $0 : nil }
        let anchorX = icon?.midX ?? visible.maxX - size.width / 2 - 8
        let x = min(max(anchorX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        panel.setFrameOrigin(CGPoint(x: x, y: visible.maxY - size.height - 6))
    }

    // MARK: - Events

    private func installMonitors() {
        // A click that reaches another app means the user clicked outside the panel. Clicks on our own
        // menu bar icon also arrive here (the menu bar is drawn by another process); its action toggles.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.iconFrame?.contains(NSEvent.mouseLocation) != true else { return }
                self.model.close()
            }
        }) { monitors.append(m) }

        // Keys reach the panel while it's key. Handled here, before the search field sees them.
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
        guard model.isOpen else { return false }
        switch keyCode {
        case 53: model.close() // Esc
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
}
